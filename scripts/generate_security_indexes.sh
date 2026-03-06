#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-.}"

INVENTORY_CSV="$OUT_DIR/02-API-INVENTORY.csv"
NO_AUTH_CSV="$OUT_DIR/03-NO-AUTH-ENDPOINTS.csv"
COOKIE_DEP_CSV="$OUT_DIR/03-COOKIE-DEPENDENT-ENDPOINTS.csv"
SPECIAL_POLICY_CSV="$OUT_DIR/03-SPECIAL-RATE-OR-RETRY-ENDPOINTS.csv"
MULTIPART_CSV="$OUT_DIR/05-MULTIPART-ENDPOINTS.csv"

for f in "$INVENTORY_CSV" "$NO_AUTH_CSV" "$COOKIE_DEP_CSV" "$SPECIAL_POLICY_CSV" "$MULTIPART_CSV"; do
  if [[ ! -f "$f" ]]; then
    echo "Required input file missing: $f" >&2
    exit 1
  fi
done

CLASSIFICATION_CSV="$OUT_DIR/08-SECURITY-CLASSIFICATION.csv"
SUMMARY_RISK_CSV="$OUT_DIR/08-SECURITY-SUMMARY-BY-RISK.csv"
SUMMARY_PACKAGE_CSV="$OUT_DIR/08-SECURITY-SUMMARY-BY-PACKAGE.csv"
SECRET_SURFACES_CSV="$OUT_DIR/08-SECRET-SURFACES.csv"

awk -F',' '
BEGIN{OFS=","}
function clean(s){gsub(/"/,"",s); return s}
function pkg(platform){
  if (platform=="health" || platform=="tikhub" || platform=="temp_mail" || platform=="hybrid" || platform=="ios_shortcut") return "skill-tikhub-core"
  if (platform=="douyin" || platform=="xigua" || platform=="toutiao" || platform=="weibo" || platform=="xiaohongshu") return "skill-tikhub-douyin-family"
  if (platform=="tiktok" || platform=="instagram" || platform=="twitter" || platform=="threads" || platform=="reddit" || platform=="linkedin" || platform=="youtube") return "skill-tikhub-global-social"
  if (platform=="bilibili" || platform=="kuaishou" || platform=="pipixia" || platform=="lemon8" || platform=="wechat_mp" || platform=="wechat_channels" || platform=="zhihu") return "skill-tikhub-video-community"
  if (platform=="sora2" || platform=="demo") return "skill-tikhub-experimental"
  return "unassigned"
}

FNR==1{next}
FILENAME==ARGV[1]{ op=clean($3); noauth[op]=1; next }
FILENAME==ARGV[2]{ op=clean($3); cookiedep[op]=1; next }
FILENAME==ARGV[3]{ op=clean($4); special[op]=1; next }
FILENAME==ARGV[4]{ op=clean($3); multipart[op]=1; next }

FILENAME==ARGV[5]{
  method=clean($1)
  path=clean($2)
  op=clean($3)
  platform=clean($4)
  module=clean($5)
  endpoint=clean($6)
  action=clean($7)

  is_noauth=((op in noauth) ? "true" : "false")
  is_cookie=((op in cookiedep) ? "true" : "false")
  is_multipart=((op in multipart) ? "true" : "false")
  is_special=((op in special) ? "true" : "false")
  requires_bearer = (is_noauth=="true" ? "false" : "true")

  if (is_cookie=="true" || is_multipart=="true") sensitivity="HIGH"
  else if (requires_bearer=="true") sensitivity="MEDIUM"
  else sensitivity="LOW"

  if (is_cookie=="true" || is_multipart=="true") risk="CRITICAL"
  else if (is_noauth=="true" || is_special=="true") risk="HIGH"
  else risk="MEDIUM"

  if (is_cookie=="true" || is_multipart=="true") redaction="STRICT"
  else if (requires_bearer=="true") redaction="STANDARD"
  else redaction="MINIMAL"

  if (is_cookie=="true") secret_scope="API_KEY+COOKIE"
  else if (requires_bearer=="true") secret_scope="API_KEY"
  else secret_scope="NONE"

  print op,action,pkg(platform),method,path,platform,module,endpoint,requires_bearer,is_noauth,is_cookie,is_multipart,is_special,sensitivity,risk,redaction,secret_scope
}
' "$NO_AUTH_CSV" "$COOKIE_DEP_CSV" "$SPECIAL_POLICY_CSV" "$MULTIPART_CSV" "$INVENTORY_CSV" \
| {
  echo "operation_id,action_name,skill_package,method,path,platform,module,endpoint,requires_bearer,is_no_auth,is_cookie_dependent,is_multipart,has_special_runtime_policy,sensitivity_class,security_risk_tier,log_redaction_profile,secret_scope"
  sort
} > "$CLASSIFICATION_CSV"

(
  echo "security_risk_tier,operation_count"
  awk -F',' 'NR>1{c[$15]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$CLASSIFICATION_CSV" | sort -t, -k2,2nr -k1,1
) > "$SUMMARY_RISK_CSV"

(
  echo "skill_package,security_risk_tier,operation_count"
  awk -F',' 'NR>1{key=$3"|"$15; c[key]++} END{for(k in c){split(k,a,"|"); printf "%s,%s,%d\n",a[1],a[2],c[k]}}' "$CLASSIFICATION_CSV" | sort -t, -k1,1 -k2,2
) > "$SUMMARY_PACKAGE_CSV"

(
  echo "operation_id,action_name,path,secret_scope,log_redaction_profile"
  awk -F',' 'NR>1{
    scope=$17; gsub(/"/,"",scope);
    if (scope!="NONE") print $1","$2","$5","$17","$16;
  }' "$CLASSIFICATION_CSV" | sort
) > "$SECRET_SURFACES_CSV"

TOTAL=$(awk -F',' 'NR>1{n++} END{print n+0}' "$CLASSIFICATION_CSV")
CRIT=$(awk -F',' 'NR>1 && $15=="CRITICAL"{n++} END{print n+0}' "$CLASSIFICATION_CSV")
HIGH=$(awk -F',' 'NR>1 && $15=="HIGH"{n++} END{print n+0}' "$CLASSIFICATION_CSV")
MED=$(awk -F',' 'NR>1 && $15=="MEDIUM"{n++} END{print n+0}' "$CLASSIFICATION_CSV")
SECRET=$(awk -F',' 'NR>1 && $17!="NONE"{n++} END{print n+0}' "$CLASSIFICATION_CSV")

cat <<REPORT
Generated files:
- $CLASSIFICATION_CSV
- $SUMMARY_RISK_CSV
- $SUMMARY_PACKAGE_CSV
- $SECRET_SURFACES_CSV

Stats:
- total_operations=$TOTAL
- critical_risk=$CRIT
- high_risk=$HIGH
- medium_risk=$MED
- secret_touching_operations=$SECRET
REPORT
