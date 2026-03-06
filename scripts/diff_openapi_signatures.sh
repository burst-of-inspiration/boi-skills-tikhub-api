#!/usr/bin/env bash
set -euo pipefail

OLD_SIGNATURES_CSV="${1:-}"
NEW_SIGNATURES_CSV="${2:-}"
OUT_DIR="${3:-.}"

if [[ -z "$OLD_SIGNATURES_CSV" || -z "$NEW_SIGNATURES_CSV" ]]; then
  echo "Usage: $0 <old_signatures_csv> <new_signatures_csv> [out_dir]" >&2
  exit 1
fi

if [[ ! -f "$OLD_SIGNATURES_CSV" ]]; then
  echo "Old signatures file not found: $OLD_SIGNATURES_CSV" >&2
  exit 1
fi

if [[ ! -f "$NEW_SIGNATURES_CSV" ]]; then
  echo "New signatures file not found: $NEW_SIGNATURES_CSV" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

ADDED_CSV="$OUT_DIR/11-OPENAPI-DRIFT-ADDED.csv"
REMOVED_CSV="$OUT_DIR/11-OPENAPI-DRIFT-REMOVED.csv"
CHANGED_CSV="$OUT_DIR/11-OPENAPI-DRIFT-SIGNATURE-CHANGED.csv"
SUMMARY_CSV="$OUT_DIR/11-OPENAPI-DRIFT-SUMMARY.csv"

awk -F',' '
BEGIN { OFS="," }
function clean(s) { gsub(/"/, "", s); return s }

FNR==1 { next }
NR==FNR {
  op=clean($1)
  old_method[op]=clean($2)
  old_path[op]=clean($3)
  old_pkg[op]=clean($6)
  old_hash[op]=clean($14)
  next
}
{
  op=clean($1)
  new_method[op]=clean($2)
  new_path[op]=clean($3)
  new_pkg[op]=clean($6)
  new_hash[op]=clean($14)
}
END {
  print "operation_id,method,path,skill_package,operation_signature_sha256" > "'"$ADDED_CSV"'"
  print "operation_id,method,path,skill_package,operation_signature_sha256" > "'"$REMOVED_CSV"'"
  print "operation_id,old_method,new_method,old_path,new_path,old_skill_package,new_skill_package,old_signature_sha256,new_signature_sha256,change_type" > "'"$CHANGED_CSV"'"

  for (op in new_hash) {
    if (!(op in old_hash)) {
      print op, new_method[op], new_path[op], new_pkg[op], new_hash[op] >> "'"$ADDED_CSV"'"
      added++
    }
  }

  for (op in old_hash) {
    if (!(op in new_hash)) {
      print op, old_method[op], old_path[op], old_pkg[op], old_hash[op] >> "'"$REMOVED_CSV"'"
      removed++
    }
  }

  for (op in old_hash) {
    if (op in new_hash && old_hash[op] != new_hash[op]) {
      ct=(old_method[op] != new_method[op] || old_path[op] != new_path[op]) ? "path_or_method_changed" : "operation_signature_hash_changed"
      print op, old_method[op], new_method[op], old_path[op], new_path[op], old_pkg[op], new_pkg[op], old_hash[op], new_hash[op], ct >> "'"$CHANGED_CSV"'"
      changed++
    }
  }

  print "drift_type,count" > "'"$SUMMARY_CSV"'"
  print "added," (added+0) >> "'"$SUMMARY_CSV"'"
  print "removed," (removed+0) >> "'"$SUMMARY_CSV"'"
  print "signature_changed," (changed+0) >> "'"$SUMMARY_CSV"'"
}
' "$OLD_SIGNATURES_CSV" "$NEW_SIGNATURES_CSV"

ADDED_COUNT=$(awk -F',' 'NR>1{n++} END{print n+0}' "$ADDED_CSV")
REMOVED_COUNT=$(awk -F',' 'NR>1{n++} END{print n+0}' "$REMOVED_CSV")
CHANGED_COUNT=$(awk -F',' 'NR>1{n++} END{print n+0}' "$CHANGED_CSV")

cat <<REPORT
Generated files:
- $ADDED_CSV
- $REMOVED_CSV
- $CHANGED_CSV
- $SUMMARY_CSV

Stats:
- added=$ADDED_COUNT
- removed=$REMOVED_COUNT
- signature_changed=$CHANGED_COUNT
REPORT
