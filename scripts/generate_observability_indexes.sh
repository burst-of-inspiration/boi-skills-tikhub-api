#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-.}"

TEST_MATRIX_CSV="$OUT_DIR/07-TEST-MATRIX.csv"
SEC_CLASS_CSV="$OUT_DIR/08-SECURITY-CLASSIFICATION.csv"
ERR_CAT_CSV="$OUT_DIR/06-ERROR-CATEGORY-MAPPING.csv"

for f in "$TEST_MATRIX_CSV" "$SEC_CLASS_CSV" "$ERR_CAT_CSV"; do
  if [[ ! -f "$f" ]]; then
    echo "Required input file missing: $f" >&2
    exit 1
  fi
done

OBS_MATRIX_CSV="$OUT_DIR/10-OBSERVABILITY-MATRIX.csv"
OBS_SLO_SUMMARY_CSV="$OUT_DIR/10-OBSERVABILITY-SUMMARY-BY-SLO.csv"
OBS_PACKAGE_SUMMARY_CSV="$OUT_DIR/10-OBSERVABILITY-SUMMARY-BY-PACKAGE.csv"
ALERT_CATALOG_CSV="$OUT_DIR/10-ALERT-CATALOG.csv"

awk -F',' '
BEGIN{OFS=","}
function clean(s){gsub(/"/,"",s); return s}
function contains(h,n){return index(h,n)>0}

FNR==1{next}
FILENAME==ARGV[1]{
  op=clean($1)
  sec_risk[op]=clean($15)
  sec_redaction[op]=clean($16)
  next
}
FILENAME==ARGV[2]{
  op=clean($1)
  action=clean($2)
  pkg=clean($3)
  method=clean($4)
  path=clean($5)
  platform=clean($6)
  module=clean($7)
  test_tier=clean($13)
  tags=clean($15)

  sr=(op in sec_risk)?sec_risk[op]:"MEDIUM"
  red=(op in sec_redaction)?sec_redaction[op]:"STANDARD"

  has_cookie=(contains(tags,"cookie_dependent")?"true":"false")
  has_special=(contains(tags,"special_runtime_policy")?"true":"false")
  has_pagination=(contains(tags,"pagination_")?"true":"false")
  is_noauth=(contains(tags,"no_auth")?"true":"false")

  if (test_tier=="critical" || sr=="CRITICAL") {
    slo_tier="SLO1"
    availability_target="99.5"
    p95_latency_ms="8000"
    error_budget_pct="0.5"
    alert_profile="critical"
    success_log_sample_pct="10"
  } else if (test_tier=="high" || sr=="HIGH") {
    slo_tier="SLO2"
    availability_target="99.0"
    p95_latency_ms="12000"
    error_budget_pct="1.0"
    alert_profile="high"
    success_log_sample_pct="5"
  } else {
    slo_tier="SLO3"
    availability_target="98.0"
    p95_latency_ms="20000"
    error_budget_pct="2.0"
    alert_profile="standard"
    success_log_sample_pct="1"
  }

  print op,action,pkg,method,path,platform,module,test_tier,sr,slo_tier,availability_target,p95_latency_ms,error_budget_pct,alert_profile,red,has_cookie,has_special,has_pagination,is_noauth,success_log_sample_pct
}
' "$SEC_CLASS_CSV" "$TEST_MATRIX_CSV" \
| {
  echo "operation_id,action_name,skill_package,method,path,platform,module,test_tier,security_risk_tier,slo_tier,availability_target_pct,p95_latency_target_ms,error_budget_pct,alert_profile,log_redaction_profile,is_cookie_dependent,has_special_runtime_policy,has_pagination,is_no_auth,success_log_sample_pct"
  sort
} > "$OBS_MATRIX_CSV"

(
  echo "slo_tier,operation_count"
  awk -F',' 'NR>1{c[$10]++} END{for(k in c) printf "%s,%d\n",k,c[k]}' "$OBS_MATRIX_CSV" | sort -t, -k2,2nr -k1,1
) > "$OBS_SLO_SUMMARY_CSV"

(
  echo "skill_package,slo_tier,operation_count"
  awk -F',' 'NR>1{key=$3"|"$10; c[key]++} END{for(k in c){split(k,a,"|"); printf "%s,%s,%d\n",a[1],a[2],c[k]}}' "$OBS_MATRIX_CSV" | sort -t, -k1,1 -k2,2
) > "$OBS_PACKAGE_SUMMARY_CSV"

(
  echo "error_category,severity_default,retryable_default,alert_severity,default_trigger"
  awk 'NR>1{
    line=$0
    cat=line
    sub(/,.*/, "", cat)

    if (!match(line, /(true|false),(high|medium|low),[^,]*$/)) {
      next
    }

    tail=substr(line, RSTART, RLENGTH)
    split(tail, parts, ",")
    r=parts[1]
    sev=parts[2]

    if (sev=="high") asev="P1";
    else if (sev=="medium") asev="P2";
    else asev="P3";
    if (cat=="RATE_LIMITED") trig="5m rate > 5%";
    else if (cat=="UPSTREAM_5XX") trig="5m rate > 2%";
    else if (cat=="TIMEOUT" || cat=="NETWORK_ERROR") trig="5m rate > 1%";
    else if (cat=="AUTH_ERROR" || cat=="PERMISSION_ERROR") trig="5m count > 20";
    else if (cat=="CONTRACT_VIOLATION") trig="any occurrence";
    else trig="5m rate > 3%";
    print cat","sev","r","asev","trig;
  }' "$ERR_CAT_CSV"
) > "$ALERT_CATALOG_CSV"

TOTAL=$(awk -F',' 'NR>1{n++} END{print n+0}' "$OBS_MATRIX_CSV")
SLO1=$(awk -F',' 'NR>1 && $10=="SLO1"{n++} END{print n+0}' "$OBS_MATRIX_CSV")
SLO2=$(awk -F',' 'NR>1 && $10=="SLO2"{n++} END{print n+0}' "$OBS_MATRIX_CSV")
SLO3=$(awk -F',' 'NR>1 && $10=="SLO3"{n++} END{print n+0}' "$OBS_MATRIX_CSV")

cat <<REPORT
Generated files:
- $OBS_MATRIX_CSV
- $OBS_SLO_SUMMARY_CSV
- $OBS_PACKAGE_SUMMARY_CSV
- $ALERT_CATALOG_CSV

Stats:
- total_operations=$TOTAL
- slo1=$SLO1
- slo2=$SLO2
- slo3=$SLO3
REPORT
