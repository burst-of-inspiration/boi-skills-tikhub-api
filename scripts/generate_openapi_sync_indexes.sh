#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi

OPENAPI_FILE="${1:-/tmp/tikhub-openapi.json}"
OUT_DIR="${2:-.}"
SOURCE_URL="${3:-https://api.tikhub.io/openapi.json}"

if [[ ! -f "$OPENAPI_FILE" ]]; then
  echo "OpenAPI file not found: $OPENAPI_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

SNAPSHOT_META_CSV="$OUT_DIR/11-OPENAPI-SNAPSHOT-METADATA.csv"
OP_SIGNATURES_CSV="$OUT_DIR/11-OPENAPI-OPERATION-SIGNATURES.csv"
SYNC_PKG_SUMMARY_CSV="$OUT_DIR/11-OPENAPI-SYNC-SUMMARY-BY-PACKAGE.csv"
SYNC_PLATFORM_SUMMARY_CSV="$OUT_DIR/11-OPENAPI-SYNC-SUMMARY-BY-PLATFORM.csv"
CHANGE_RULES_CSV="$OUT_DIR/11-OPENAPI-CHANGE-RISK-RULES.csv"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

csv_escape() {
  local s="${1//$'\n'/\\n}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

pkg_from_platform() {
  local platform="$1"
  case "$platform" in
    health|tikhub|temp_mail|hybrid|ios_shortcut)
      echo "skill-tikhub-core"
      ;;
    douyin|xigua|toutiao|weibo|xiaohongshu)
      echo "skill-tikhub-douyin-family"
      ;;
    tiktok|instagram|twitter|threads|reddit|linkedin|youtube)
      echo "skill-tikhub-global-social"
      ;;
    bilibili|kuaishou|pipixia|lemon8|wechat_mp|wechat_channels|zhihu)
      echo "skill-tikhub-video-community"
      ;;
    sora2|demo)
      echo "skill-tikhub-experimental"
      ;;
    *)
      echo "unassigned"
      ;;
  esac
}

TMP_TSV="$(mktemp)"
trap 'rm -f "$TMP_TSV"' EXIT

jq -r '
  .paths
  | to_entries[]
  | .key as $path
  | .value
  | to_entries[]
  | select(.key | test("^(get|post|put|delete|patch|head|options|trace)$"))
  | .key as $method
  | .value as $op
  | ($path | split("/")) as $parts
  | ($parts[3] // "unknown") as $platform
  | (if ($parts | length) > 4 then $parts[4] else "root" end) as $mod
  | ($op.operationId // ($method + "_" + ($path | gsub("[^A-Za-z0-9]+"; "_")))) as $operation_id
  | (
      if ($op.requestBody.content["multipart/form-data"] != null) then "MULTIPART"
      elif ($op.requestBody.content["application/json"] != null) then "JSON"
      else "NONE"
      end
    ) as $request_profile
  | (
      if ($op.responses["302"] != null) then "REDIRECT"
      elif ($op.responses["200"].content["application/json"].schema["$ref"] == "#/components/schemas/ResponseModel") then "RESPONSE_MODEL"
      elif ($op.responses["200"].content["application/json"].schema["$ref"] == null) then "INLINE_OR_NONE"
      else "CUSTOM_MODEL"
      end
    ) as $response_profile
  | (($op.responses | keys | sort | join("|")) // "NONE") as $declared_status_codes
  | ((($op.responses | keys | index("422")) != null) | tostring) as $has_422
  | (
      [($op.parameters // [])[]
        | "\(.in // "query"):\(.name // ""):\(.required // false):\(.schema.type // .schema["$ref"] // "any")"
      ] | sort | join("|")
      | if . == "" then "NONE" else . end
    ) as $parameter_signature
  | ((($op.requestBody.content // {}) | keys | sort | join("|"))) as $request_body_media_types
  | ($op.responses["200"].content["application/json"].schema["$ref"] // "(inline_or_none)") as $response_schema_ref
  | [
      $operation_id,
      $method,
      $path,
      $platform,
      $mod,
      $request_profile,
      $response_profile,
      $declared_status_codes,
      $has_422,
      $parameter_signature,
      ($request_body_media_types | if . == "" then "NONE" else . end),
      $response_schema_ref
    ]
  | @tsv
' "$OPENAPI_FILE" | sort > "$TMP_TSV"

{
  echo "operation_id,method,path,platform,module,skill_package,request_profile,response_profile,declared_status_codes,has_422_declared,parameter_signature,request_body_media_types,response_schema_ref,operation_signature_sha256"
  while IFS=$'\t' read -r operation_id method path platform module request_profile response_profile declared_status_codes has_422 parameter_signature request_body_media_types response_schema_ref; do
    [[ -z "${operation_id}${method}${path}" ]] && continue

    skill_package="$(pkg_from_platform "$platform")"
    signature_payload="${method}|${path}|${request_profile}|${response_profile}|${declared_status_codes}|${has_422}|${parameter_signature}|${request_body_media_types}|${response_schema_ref}"
    signature_hash="$(printf '%s' "$signature_payload" | sha256_stdin)"

    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
      "$(csv_escape "$operation_id")" \
      "$(csv_escape "$method")" \
      "$(csv_escape "$path")" \
      "$(csv_escape "$platform")" \
      "$(csv_escape "$module")" \
      "$(csv_escape "$skill_package")" \
      "$(csv_escape "$request_profile")" \
      "$(csv_escape "$response_profile")" \
      "$(csv_escape "$declared_status_codes")" \
      "$(csv_escape "$has_422")" \
      "$(csv_escape "$parameter_signature")" \
      "$(csv_escape "$request_body_media_types")" \
      "$(csv_escape "$response_schema_ref")" \
      "$(csv_escape "$signature_hash")"
  done < "$TMP_TSV"
} > "$OP_SIGNATURES_CSV"

{
  echo "skill_package,operation_count"
  awk -F',' '
    NR>1{
      pkg=$6
      gsub(/"/,"",pkg)
      c[pkg]++
    }
    END{
      for(k in c) print k "," c[k]
    }
  ' "$OP_SIGNATURES_CSV" | sort -t, -k2,2nr -k1,1
} > "$SYNC_PKG_SUMMARY_CSV"

{
  echo "platform,operation_count"
  awk -F',' '
    NR>1{
      platform=$4
      gsub(/"/,"",platform)
      c[platform]++
    }
    END{
      for(k in c) print k "," c[k]
    }
  ' "$OP_SIGNATURES_CSV" | sort -t, -k2,2nr -k1,1
} > "$SYNC_PLATFORM_SUMMARY_CSV"

{
  echo "change_type,detected_by,severity,required_action"
  echo "operation_added,operation_id exists in new snapshot but not in baseline,medium,add adapter tests and update package changelog"
  echo "operation_removed,operation_id missing in new snapshot but exists in baseline,high,mark breaking change and remove/deprecate action"
  echo "path_or_method_changed,method/path tuple changed for existing operation_id,high,update routing adapter and integration tests"
  echo "request_profile_changed,request profile NONE/JSON/MULTIPART changed,high,update request serializer and fixtures"
  echo "response_profile_changed,response envelope profile changed,high,update response mapper and contract tests"
  echo "status_codes_changed,declared response status set changed,medium,update error mapping and retry policy verification"
  echo "has_422_changed,validation status declaration added or removed,medium,update validation and negative test plan"
  echo "parameter_signature_changed,parameter set/requiredness/type changed,high,update input validation and docs"
  echo "request_body_media_changed,request body media type set changed,high,update content-type handling and tests"
  echo "response_schema_ref_changed,200-response schema reference changed,high,update parser and normalized mapping"
  echo "operation_signature_hash_changed,any contract-significant field changed,high,run full package regression for impacted operations"
} > "$CHANGE_RULES_CSV"

FILE_SHA256="$(sha256_file "$OPENAPI_FILE")"
SNAPSHOT_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OPENAPI_VERSION="$(jq -r '.openapi // ""' "$OPENAPI_FILE")"
API_VERSION="$(jq -r '.info.version // ""' "$OPENAPI_FILE")"
API_TITLE="$(jq -r '.info.title // ""' "$OPENAPI_FILE")"
PATH_COUNT="$(jq '.paths | length' "$OPENAPI_FILE")"
OPERATION_COUNT="$(awk 'END{print NR+0}' "$TMP_TSV")"
GET_COUNT="$(awk -F'\t' '$2=="get"{n++} END{print n+0}' "$TMP_TSV")"
POST_COUNT="$(awk -F'\t' '$2=="post"{n++} END{print n+0}' "$TMP_TSV")"
OTHER_METHOD_COUNT=$((OPERATION_COUNT - GET_COUNT - POST_COUNT))

{
  echo "snapshot_at_utc,source_url,file_sha256,openapi_version,api_version,api_title,path_count,operation_count,get_count,post_count,other_method_count"
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$(csv_escape "$SNAPSHOT_AT_UTC")" \
    "$(csv_escape "$SOURCE_URL")" \
    "$(csv_escape "$FILE_SHA256")" \
    "$(csv_escape "$OPENAPI_VERSION")" \
    "$(csv_escape "$API_VERSION")" \
    "$(csv_escape "$API_TITLE")" \
    "$(csv_escape "$PATH_COUNT")" \
    "$(csv_escape "$OPERATION_COUNT")" \
    "$(csv_escape "$GET_COUNT")" \
    "$(csv_escape "$POST_COUNT")" \
    "$(csv_escape "$OTHER_METHOD_COUNT")"
} > "$SNAPSHOT_META_CSV"

cat <<REPORT
Generated files:
- $SNAPSHOT_META_CSV
- $OP_SIGNATURES_CSV
- $SYNC_PKG_SUMMARY_CSV
- $SYNC_PLATFORM_SUMMARY_CSV
- $CHANGE_RULES_CSV

Stats:
- operation_count=$OPERATION_COUNT
- get_count=$GET_COUNT
- post_count=$POST_COUNT
- other_method_count=$OTHER_METHOD_COUNT
REPORT
