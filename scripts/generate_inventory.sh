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

INVENTORY_CSV="$OUT_DIR/02-API-INVENTORY.csv"
PLATFORM_SUMMARY_CSV="$OUT_DIR/02-API-SUMMARY-PLATFORM.csv"
MODULE_SUMMARY_CSV="$OUT_DIR/02-API-SUMMARY-MODULE.csv"

(
  echo "method,path,operation_id,platform,module,endpoint,action_name"
  jq -r '.paths | to_entries[] | .key as $path | .value | to_entries[] | [.key, $path, .value.operationId] | @tsv' "$OPENAPI_FILE" \
  | awk -F'\t' 'BEGIN{OFS=","} {
      method=$1; path=$2; op=$3;
      split(path,a,"/");
      platform=a[4];
      s5=a[5];
      if(a[6]==""){
        module="root";
        endpoint=s5;
      } else {
        module=s5;
        endpoint=a[6];
        for(i=7;i in a;i++){
          endpoint=endpoint"_"a[i];
        }
      }
      gsub(/[^a-zA-Z0-9_]/,"_",endpoint);
      action=platform"."module"."endpoint;
      print method,path,op,platform,module,endpoint,action;
    }' \
  | sort
) > "$INVENTORY_CSV"

(
  echo "platform,operation_count"
  awk -F',' 'NR>1{c[$4]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$INVENTORY_CSV" \
  | sort -t, -k2,2nr -k1,1
) > "$PLATFORM_SUMMARY_CSV"

(
  echo "platform,module,operation_count"
  awk -F',' 'NR>1{k=$4"|"$5; c[k]++} END{for(k in c){split(k,a,"|"); printf "%s,%s,%d\n",a[1],a[2],c[k]}}' "$INVENTORY_CSV" \
  | sort -t, -k1,1 -k3,3nr -k2,2
) > "$MODULE_SUMMARY_CSV"

TOTAL_OPS=$(awk -F',' 'NR>1{n++} END{print n+0}' "$INVENTORY_CSV")
TOTAL_PLATFORMS=$(awk -F',' 'NR>1{p[$4]=1} END{for(k in p)c++; print c+0}' "$INVENTORY_CSV")

cat <<REPORT
Generated files:
- $INVENTORY_CSV
- $PLATFORM_SUMMARY_CSV
- $MODULE_SUMMARY_CSV

Stats:
- total_operations=$TOTAL_OPS
- total_platforms=$TOTAL_PLATFORMS
REPORT
