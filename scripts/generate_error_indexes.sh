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

ERROR_SURFACES_CSV="$OUT_DIR/06-ERROR-SURFACES.csv"
STATUS_SUMMARY_CSV="$OUT_DIR/06-ERROR-STATUS-SUMMARY.csv"
NO_422_CSV="$OUT_DIR/06-NO-422-ENDPOINTS.csv"
NO_422_PLATFORM_SUMMARY_CSV="$OUT_DIR/06-NO-422-SUMMARY-BY-PLATFORM.csv"

jq -r '
  .paths
  | to_entries[]
  | .key as $path
  | .value
  | to_entries[]
  | .key as $method
  | .value as $op
  | ($op.responses | keys) as $codes
  | (($codes | index("200")) != null) as $has_200
  | (($codes | index("302")) != null) as $has_302
  | (($codes | index("422")) != null) as $has_422
  | ($op.responses["200"].content["application/json"].schema["$ref"] // "(inline_or_none)") as $response_schema_ref
  | (if $has_302 then "REDIRECT"
     elif $response_schema_ref == "#/components/schemas/ResponseModel" then "RESPONSE_MODEL"
     elif $response_schema_ref == "(inline_or_none)" then "INLINE_OR_NONE"
     else "CUSTOM_MODEL"
     end) as $response_profile
  | [
      $method,
      $path,
      ($op.operationId // ""),
      ($path | split("/")[3]),
      (if (($path | split("/") | length) > 5) then ($path | split("/")[4]) else "root" end),
      ($codes | join("|")),
      $has_200,
      $has_302,
      $has_422,
      $response_profile,
      $response_schema_ref
    ]
  | @csv
' "$OPENAPI_FILE" \
| {
  echo "method,path,operation_id,platform,module,declared_status_codes,has_200,has_302,has_422,response_profile,response_schema_ref"
  sort
} > "$ERROR_SURFACES_CSV"

(
  echo "status_code,operation_count"
  jq -r '.paths | to_entries[] | .value | to_entries[] | .value.responses | keys[]' "$OPENAPI_FILE" \
  | sort | uniq -c | awk '{print $2","$1}'
) > "$STATUS_SUMMARY_CSV"

(
  echo "method,path,operation_id,platform,module,declared_status_codes,response_profile"
  awk -F',' 'NR>1{
    m=$1; p=$2; op=$3; plat=$4; mod=$5; codes=$6; has422=$9; rp=$10;
    gsub(/"/,"",m); gsub(/"/,"",p); gsub(/"/,"",op); gsub(/"/,"",plat); gsub(/"/,"",mod); gsub(/"/,"",codes); gsub(/"/,"",has422); gsub(/"/,"",rp);
    if (has422=="false") print m "," p "," op "," plat "," mod "," codes "," rp;
  }' "$ERROR_SURFACES_CSV" | sort
) > "$NO_422_CSV"

(
  echo "platform,no_422_operation_count"
  awk -F',' 'NR>1{plat=$4; gsub(/"/,"",plat); c[plat]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$NO_422_CSV" \
  | sort -t, -k2,2nr -k1,1
) > "$NO_422_PLATFORM_SUMMARY_CSV"

TOTAL_OPS=$(awk -F',' 'NR>1{n++} END{print n+0}' "$ERROR_SURFACES_CSV")
NO_422_COUNT=$(awk -F',' 'NR>1{n++} END{print n+0}' "$NO_422_CSV")
REDIRECT_COUNT=$(awk -F',' 'NR>1{rp=$10; gsub(/"/,"",rp); if(rp=="REDIRECT") n++} END{print n+0}' "$ERROR_SURFACES_CSV")

cat <<REPORT
Generated files:
- $ERROR_SURFACES_CSV
- $STATUS_SUMMARY_CSV
- $NO_422_CSV
- $NO_422_PLATFORM_SUMMARY_CSV

Stats:
- total_operations=$TOTAL_OPS
- no_422_operations=$NO_422_COUNT
- redirect_profile_operations=$REDIRECT_COUNT
REPORT
