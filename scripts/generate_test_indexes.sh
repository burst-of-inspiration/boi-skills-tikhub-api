#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-.}"

INVENTORY_CSV="$OUT_DIR/02-API-INVENTORY.csv"
NO_AUTH_CSV="$OUT_DIR/03-NO-AUTH-ENDPOINTS.csv"
COOKIE_DEP_CSV="$OUT_DIR/03-COOKIE-DEPENDENT-ENDPOINTS.csv"
SPECIAL_POLICY_CSV="$OUT_DIR/03-SPECIAL-RATE-OR-RETRY-ENDPOINTS.csv"
CONTRACT_PROFILE_CSV="$OUT_DIR/05-CONTRACT-PROFILES.csv"
NONSTANDARD_RESPONSE_CSV="$OUT_DIR/05-NONSTANDARD-RESPONSE-ENDPOINTS.csv"
MULTIPART_CSV="$OUT_DIR/05-MULTIPART-ENDPOINTS.csv"
NO_422_CSV="$OUT_DIR/06-NO-422-ENDPOINTS.csv"

for f in "$INVENTORY_CSV" "$NO_AUTH_CSV" "$COOKIE_DEP_CSV" "$SPECIAL_POLICY_CSV" "$CONTRACT_PROFILE_CSV" "$NONSTANDARD_RESPONSE_CSV" "$MULTIPART_CSV" "$NO_422_CSV"; do
  if [[ ! -f "$f" ]]; then
    echo "Required input file missing: $f" >&2
    exit 1
  fi
done

MATRIX_CSV="$OUT_DIR/07-TEST-MATRIX.csv"
SUMMARY_TIER_CSV="$OUT_DIR/07-TEST-SUMMARY-BY-TIER.csv"
SUMMARY_PACKAGE_CSV="$OUT_DIR/07-TEST-SUMMARY-BY-PACKAGE.csv"
CRITICAL_CSV="$OUT_DIR/07-CRITICAL-OPERATIONS.csv"

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
function addtag(tag){ if(tags=="") tags=tag; else tags=tags"|"tag }

FNR==1{next}
FILENAME==ARGV[1]{ op=clean($3); noauth[op]=1; next }
FILENAME==ARGV[2]{ op=clean($3); cookiedep[op]=1; next }
FILENAME==ARGV[3]{ op=clean($4); special[op]=1; next }
FILENAME==ARGV[4]{ op=clean($3); req[op]=clean($6); resp[op]=clean($12); pag[op]=clean($15); has422[op]=clean($14); next }
FILENAME==ARGV[5]{ op=clean($3); nonstd[op]=1; next }
FILENAME==ARGV[6]{ op=clean($3); multipart[op]=1; next }
FILENAME==ARGV[7]{ op=clean($3); no422[op]=1; next }

FILENAME==ARGV[8]{
  method=clean($1)
  path=clean($2)
  op=clean($3)
  platform=clean($4)
  module=clean($5)
  endpoint=clean($6)
  action=clean($7)

  method_l=tolower(method)
  is_post=(method_l=="post")
  is_noauth=(op in noauth)
  is_cookie=(op in cookiedep)
  is_special=(op in special)
  is_nonstd=(op in nonstd)
  is_multipart=(op in multipart)
  is_no422=(op in no422)

  rp=(op in req)?req[op]:"UNKNOWN"
  rsp=(op in resp)?resp[op]:"UNKNOWN"
  pp=(op in pag)?pag[op]:"UNKNOWN"
  h422=(op in has422)?has422[op]:"unknown"

  tags=""
  if (is_post) addtag("post")
  if (is_noauth) addtag("no_auth")
  if (is_cookie) addtag("cookie_dependent")
  if (is_special) addtag("special_runtime_policy")
  if (is_nonstd) addtag("nonstandard_response")
  if (is_multipart) addtag("multipart")
  if (is_no422) addtag("no_422_declared")
  if (pp!="NONE" && pp!="UNKNOWN") addtag("pagination_" tolower(pp))
  if (rp=="JSON") addtag("json_body")

  if (is_post || is_cookie || is_special || is_multipart || is_nonstd) {
    tier="critical"
    required_tests="unit|contract|integration|live_smoke|regression"
  } else if ((pp!="NONE" && pp!="UNKNOWN") || rp=="JSON" || is_no422 || is_noauth) {
    tier="high"
    required_tests="unit|contract|integration|regression"
  } else {
    tier="standard"
    required_tests="unit|contract"
  }

  print op,action,pkg(platform),method,path,platform,module,endpoint,rp,rsp,pp,h422,tier,required_tests,tags
}
' "$NO_AUTH_CSV" "$COOKIE_DEP_CSV" "$SPECIAL_POLICY_CSV" "$CONTRACT_PROFILE_CSV" "$NONSTANDARD_RESPONSE_CSV" "$MULTIPART_CSV" "$NO_422_CSV" "$INVENTORY_CSV" \
| {
  echo "operation_id,action_name,skill_package,method,path,platform,module,endpoint,request_profile,response_profile,pagination_profile,has_422_declared,test_tier,required_test_suites,tags"
  sort
} > "$MATRIX_CSV"

(
  echo "test_tier,operation_count"
  awk -F',' 'NR>1{c[$13]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$MATRIX_CSV" | sort -t, -k2,2nr -k1,1
) > "$SUMMARY_TIER_CSV"

(
  echo "skill_package,test_tier,operation_count"
  awk -F',' 'NR>1{key=$3"|"$13; c[key]++} END{for(k in c){split(k,a,"|"); printf "%s,%s,%d\n",a[1],a[2],c[k]}}' "$MATRIX_CSV" | sort -t, -k1,1 -k2,2
) > "$SUMMARY_PACKAGE_CSV"

(
  echo "operation_id,action_name,skill_package,method,path,platform,module,required_test_suites,tags"
  awk -F',' 'NR>1 && $13=="critical"{print $1","$2","$3","$4","$5","$6","$7","$14","$15}' "$MATRIX_CSV" | sort
) > "$CRITICAL_CSV"

TOTAL=$(awk -F',' 'NR>1{n++} END{print n+0}' "$MATRIX_CSV")
CRITICAL=$(awk -F',' 'NR>1 && $13=="critical"{n++} END{print n+0}' "$MATRIX_CSV")
HIGH=$(awk -F',' 'NR>1 && $13=="high"{n++} END{print n+0}' "$MATRIX_CSV")
STANDARD=$(awk -F',' 'NR>1 && $13=="standard"{n++} END{print n+0}' "$MATRIX_CSV")

cat <<REPORT
Generated files:
- $MATRIX_CSV
- $SUMMARY_TIER_CSV
- $SUMMARY_PACKAGE_CSV
- $CRITICAL_CSV

Stats:
- total_operations=$TOTAL
- critical_tier=$CRITICAL
- high_tier=$HIGH
- standard_tier=$STANDARD
REPORT
