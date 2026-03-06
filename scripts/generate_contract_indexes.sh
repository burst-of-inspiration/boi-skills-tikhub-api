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

PROFILE_CSV="$OUT_DIR/05-CONTRACT-PROFILES.csv"
REQUEST_SUMMARY_CSV="$OUT_DIR/05-CONTRACT-SUMMARY-REQUEST.csv"
RESPONSE_SUMMARY_CSV="$OUT_DIR/05-CONTRACT-SUMMARY-RESPONSE.csv"
PAGINATION_SUMMARY_CSV="$OUT_DIR/05-CONTRACT-SUMMARY-PAGINATION.csv"
NONSTANDARD_RESPONSE_CSV="$OUT_DIR/05-NONSTANDARD-RESPONSE-ENDPOINTS.csv"
MULTIPART_ENDPOINTS_CSV="$OUT_DIR/05-MULTIPART-ENDPOINTS.csv"

jq -r '
  . as $root
  | .paths
  | to_entries[]
  | .key as $path
  | .value
  | to_entries[]
  | .key as $method
  | .value as $op
  | ($op.operationId // "") as $operation_id
  | (($op.parameters // []) | map(select(.in == "query"))) as $query_params
  | ($query_params | map(.name)) as $query_names
  | ($query_params | length) as $query_count
  | (if $query_count > 0 then true else false end) as $has_query_params
  | (if ($query_names | index("cookie")) != null then true else false end) as $has_cookie_query
  | (if $op.requestBody == null then [] else ($op.requestBody.content | keys) end) as $body_types
  | (if ($body_types | length) == 0 then "NONE"
     elif ($body_types | index("multipart/form-data")) != null then "MULTIPART"
     elif ($body_types | index("application/json")) != null then "JSON"
     else "OTHER"
     end) as $request_profile
  | ($op.requestBody.content["application/json"].schema["$ref"] // "") as $body_schema_ref
  | (if $body_schema_ref == "" then false
     else (($body_schema_ref | split("/") | .[-1]) as $schema
       | (($root.components.schemas[$schema].properties.cookie // null) != null))
     end) as $has_cookie_body
  | ($op.responses["200"].content["application/json"].schema["$ref"] // "(inline_or_none)") as $response_schema_ref
  | (if $op.responses["302"] != null then "REDIRECT"
     elif $response_schema_ref == "#/components/schemas/ResponseModel" then "RESPONSE_MODEL"
     elif $response_schema_ref == "(inline_or_none)" then "INLINE_OR_NONE"
     else "CUSTOM_MODEL"
     end) as $response_profile
  | (if $op.responses["422"] != null then true else false end) as $has_422
  | (if ((($query_names | index("cursor")) != null)
      or (($query_names | index("end_cursor")) != null)
      or (($query_names | index("max_cursor")) != null)
      or (($query_names | index("continuation_token")) != null)
      or (($query_names | index("pagination_token")) != null)
      or (($query_names | index("next_cursor")) != null)
      or (($query_names | index("pcursor")) != null))
      then true else false end) as $has_cursor
  | (if ($query_names | index("offset")) != null then true else false end) as $has_offset
  | (if ((($query_names | index("page")) != null)
      or (($query_names | index("page_size")) != null)
      or (($query_names | index("count")) != null))
      then true else false end) as $has_page
  | (if $has_cursor and ($has_offset or $has_page) then "MIXED"
     elif $has_cursor then "CURSOR"
     elif $has_offset then "OFFSET"
     elif $has_page then "PAGE"
     else "NONE"
     end) as $pagination_profile
  | [
      $method,
      $path,
      $operation_id,
      ($path | split("/")[3]),
      (if (($path | split("/") | length) > 5) then ($path | split("/")[4]) else "root" end),
      $request_profile,
      (if ($body_types | length) == 0 then "" else ($body_types | join("|")) end),
      $has_query_params,
      $query_count,
      $has_cookie_query,
      $has_cookie_body,
      $response_profile,
      $response_schema_ref,
      $has_422,
      $pagination_profile
    ]
  | @csv
' "$OPENAPI_FILE" \
| {
  echo "method,path,operation_id,platform,module,request_profile,body_content_types,has_query_params,query_param_count,has_cookie_query,has_cookie_body,response_profile,response_schema_ref,has_422,pagination_profile"
  sort
} > "$PROFILE_CSV"

(
  echo "request_profile,operation_count"
  awk -F',' 'NR>1{gsub(/"/,"",$6); c[$6]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$PROFILE_CSV" \
  | sort -t, -k2,2nr -k1,1
) > "$REQUEST_SUMMARY_CSV"

(
  echo "response_profile,operation_count"
  awk -F',' 'NR>1{gsub(/"/,"",$12); c[$12]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$PROFILE_CSV" \
  | sort -t, -k2,2nr -k1,1
) > "$RESPONSE_SUMMARY_CSV"

(
  echo "pagination_profile,operation_count"
  awk -F',' 'NR>1{gsub(/"/,"",$15); c[$15]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$PROFILE_CSV" \
  | sort -t, -k2,2nr -k1,1
) > "$PAGINATION_SUMMARY_CSV"

(
  echo "method,path,operation_id,response_profile,response_schema_ref"
  awk -F',' 'NR>1{
    m=$1; p=$2; op=$3; rp=$12; rs=$13;
    gsub(/"/,"",m); gsub(/"/,"",p); gsub(/"/,"",op); gsub(/"/,"",rp); gsub(/"/,"",rs);
    if (rp!="RESPONSE_MODEL") print m "," p "," op "," rp "," rs;
  }' "$PROFILE_CSV" | sort
) > "$NONSTANDARD_RESPONSE_CSV"

(
  echo "method,path,operation_id,body_content_types"
  awk -F',' 'NR>1{
    m=$1; p=$2; op=$3; rq=$6; bt=$7;
    gsub(/"/,"",m); gsub(/"/,"",p); gsub(/"/,"",op); gsub(/"/,"",rq); gsub(/"/,"",bt);
    if (rq=="MULTIPART") print m "," p "," op "," bt;
  }' "$PROFILE_CSV" | sort
) > "$MULTIPART_ENDPOINTS_CSV"

TOTAL_OPS=$(awk -F',' 'NR>1{n++} END{print n+0}' "$PROFILE_CSV")
NONSTANDARD_RESPONSE_COUNT=$(awk -F',' 'NR>1{gsub(/"/,"",$12); if($12!="RESPONSE_MODEL") n++} END{print n+0}' "$PROFILE_CSV")
MULTIPART_COUNT=$(awk -F',' 'NR>1{gsub(/"/,"",$6); if($6=="MULTIPART") n++} END{print n+0}' "$PROFILE_CSV")

cat <<REPORT
Generated files:
- $PROFILE_CSV
- $REQUEST_SUMMARY_CSV
- $RESPONSE_SUMMARY_CSV
- $PAGINATION_SUMMARY_CSV
- $NONSTANDARD_RESPONSE_CSV
- $MULTIPART_ENDPOINTS_CSV

Stats:
- total_operations=$TOTAL_OPS
- nonstandard_response_operations=$NONSTANDARD_RESPONSE_COUNT
- multipart_operations=$MULTIPART_COUNT
REPORT
