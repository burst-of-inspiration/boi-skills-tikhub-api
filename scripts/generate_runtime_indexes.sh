#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi

OPENAPI_FILE="${1:-/tmp/tikhub-openapi.json}"
OUT_DIR="${2:-.}"

if [[ ! -f "$OPENAPI_FILE" ]]; then
  echo "OpenAPI file not found: $OPENAPI_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

NO_AUTH_CSV="$OUT_DIR/03-NO-AUTH-ENDPOINTS.csv"
COOKIE_DEP_CSV="$OUT_DIR/03-COOKIE-DEPENDENT-ENDPOINTS.csv"
SPECIAL_POLICY_CSV="$OUT_DIR/03-SPECIAL-RATE-OR-RETRY-ENDPOINTS.csv"

(
  echo "method,path,operation_id,platform,module"
  jq -r '
    .paths
    | to_entries[]
    | .key as $path
    | .value
    | to_entries[]
    | select((.value.security // []) == [])
    | [
        .key,
        $path,
        .value.operationId,
        ($path | split("/")[3]),
        (if (($path | split("/") | length) > 5) then ($path | split("/")[4]) else "root" end)
      ]
    | @csv
  ' "$OPENAPI_FILE" | sort
) > "$NO_AUTH_CSV"

(
  echo "method,path,operation_id,request_schema,platform,module"
  jq -r '
    . as $root
    | .paths
    | to_entries[]
    | .key as $path
    | .value
    | to_entries[]
    | (.value.requestBody.content["application/json"].schema["$ref"] // "") as $ref
    | select($ref != "")
    | ($ref | split("/") | .[-1]) as $schema
    | select($root.components.schemas[$schema].properties.cookie != null)
    | [
        .key,
        $path,
        .value.operationId,
        $schema,
        ($path | split("/")[3]),
        (if (($path | split("/") | length) > 5) then ($path | split("/")[4]) else "root" end)
      ]
    | @csv
  ' "$OPENAPI_FILE" | sort
) > "$COOKIE_DEP_CSV"

(
  echo "rule_type,method,path,operation_id,policy_note"
  (
    jq -r '
      .paths
      | to_entries[]
      | .key as $path
      | .value
      | to_entries[]
      | .value as $op
      | ((.value.summary // "") + "\n" + (.value.description // "")) as $txt
      | select($txt | test("1 request per second|Maximum 1 request per second|每秒最多请求 1 次|间隔至少 1 秒|polling interval"; "i"))
      | ["rate_limit_1rps", .key, $path, .value.operationId, "enforce at least 1000ms interval"]
      | @csv
    ' "$OPENAPI_FILE"

    jq -r '
      .paths
      | to_entries[]
      | .key as $path
      | .value
      | to_entries[]
      | .value as $op
      | ((.value.summary // "") + "\n" + (.value.description // "")) as $txt
      | select($txt | test("retry the request 3 times|重试请求3次|error code 400"; "i"))
      | ["retry_on_400_3x", .key, $path, .value.operationId, "if code 400 then retry up to 3 times"]
      | @csv
    ' "$OPENAPI_FILE"

    jq -r '
      .paths
      | to_entries[]
      | .key as $path
      | .value
      | to_entries[]
      | select(($path | test("/interaction/(apply|collect|follow|forward|like|post_comment|reply_comment)$|/sora2/(create_video|upload_image)$")))
      | ["no_auto_retry_non_idempotent", .key, $path, .value.operationId, "disable automatic retry unless explicitly forced"]
      | @csv
    ' "$OPENAPI_FILE"
  ) | awk '!seen[$0]++' | sort
) > "$SPECIAL_POLICY_CSV"

NO_AUTH_COUNT=$(awk 'NR>1{n++} END{print n+0}' "$NO_AUTH_CSV")
COOKIE_DEP_COUNT=$(awk 'NR>1{n++} END{print n+0}' "$COOKIE_DEP_CSV")
SPECIAL_POLICY_COUNT=$(awk 'NR>1{n++} END{print n+0}' "$SPECIAL_POLICY_CSV")

cat <<REPORT
Generated files:
- $NO_AUTH_CSV
- $COOKIE_DEP_CSV
- $SPECIAL_POLICY_CSV

Stats:
- no_auth_endpoints=$NO_AUTH_COUNT
- cookie_dependent_endpoints=$COOKIE_DEP_COUNT
- special_policy_endpoints=$SPECIAL_POLICY_COUNT
REPORT
