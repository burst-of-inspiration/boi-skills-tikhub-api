#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-.}"

TEST_SUMMARY_CSV="$OUT_DIR/07-TEST-SUMMARY-BY-PACKAGE.csv"
SEC_SUMMARY_CSV="$OUT_DIR/08-SECURITY-SUMMARY-BY-PACKAGE.csv"

for f in "$TEST_SUMMARY_CSV" "$SEC_SUMMARY_CSV"; do
  if [[ ! -f "$f" ]]; then
    echo "Required input file missing: $f" >&2
    exit 1
  fi
done

BASELINE_CSV="$OUT_DIR/09-RELEASE-BASELINE-BY-PACKAGE.csv"
PRIORITY_CSV="$OUT_DIR/09-RELEASE-PRIORITY-BY-PACKAGE.csv"

awk -F',' '
BEGIN{OFS=","}
function clean(s){gsub(/"/,"",s); return s}

FNR==1{next}
FILENAME==ARGV[1]{
  pkg=clean($1); tier=clean($2); n=$3+0;
  total[pkg]+=n;
  if (tier=="critical") tcrit[pkg]=n;
  else if (tier=="high") thigh[pkg]=n;
  else if (tier=="standard") tstd[pkg]=n;
  pkgs[pkg]=1;
  next;
}
FILENAME==ARGV[2]{
  pkg=clean($1); risk=clean($2); n=$3+0;
  if (risk=="CRITICAL") scrit[pkg]=n;
  else if (risk=="HIGH") shigh[pkg]=n;
  else if (risk=="MEDIUM") smed[pkg]=n;
  pkgs[pkg]=1;
  next;
}
END{
  for (p in pkgs){
    tc=(p in tcrit)?tcrit[p]:0;
    th=(p in thigh)?thigh[p]:0;
    ts=(p in tstd)?tstd[p]:0;
    sc=(p in scrit)?scrit[p]:0;
    sh=(p in shigh)?shigh[p]:0;
    sm=(p in smed)?smed[p]:0;
    tot=(p in total)?total[p]:(tc+th+ts);
    score=(tc*3)+(th*1)+(sc*4)+(sh*2);
    printf "%s,%d,%d,%d,%d,%d,%d,%d,%d\n", p, tot, tc, th, ts, sc, sh, sm, score;
  }
}
' "$TEST_SUMMARY_CSV" "$SEC_SUMMARY_CSV" \
| {
  echo "skill_package,total_operations,test_critical,test_high,test_standard,security_critical,security_high,security_medium,release_risk_score"
  sort -t, -k9,9nr -k2,2nr -k1,1
} > "$BASELINE_CSV"

(
  echo "release_order,skill_package,release_risk_score,total_operations,recommended_strategy"
  awk -F',' 'NR>1{print}' "$BASELINE_CSV" \
  | awk -F',' 'BEGIN{OFS=","}
      {
        order=NR;
        pkg=$1; score=$9; total=$2;
        if (order<=2) strat="canary_first_then_gradual"
        else if (order<=4) strat="standard_staged_release"
        else strat="fast_follow_release"
        print order,pkg,score,total,strat;
      }'
) > "$PRIORITY_CSV"

TOTAL_PKG=$(awk -F',' 'NR>1{n++} END{print n+0}' "$BASELINE_CSV")
MAX_SCORE=$(awk -F',' 'NR>1{if($9>m)m=$9} END{print m+0}' "$BASELINE_CSV")

cat <<REPORT
Generated files:
- $BASELINE_CSV
- $PRIORITY_CSV

Stats:
- total_packages=$TOTAL_PKG
- max_release_risk_score=$MAX_SCORE
REPORT
