# 11 OpenAPI Sync Checklist

Status: Draft v1.0  
Last Updated: 2026-03-06

## Snapshot And Baseline
- [ ] Latest OpenAPI downloaded and saved to snapshot path.
- [ ] `11-OPENAPI-SNAPSHOT-METADATA.csv` regenerated.
- [ ] `11-OPENAPI-OPERATION-SIGNATURES.csv` regenerated.
- [ ] package/platform summary CSVs regenerated.

## Drift Analysis
- [ ] Diff script executed against previous baseline signatures.
- [ ] `11-OPENAPI-DRIFT-SUMMARY.csv` attached to PR.
- [ ] Added/removed/changed operation lists reviewed.
- [ ] Drift severity classified using `11-OPENAPI-CHANGE-RISK-RULES.csv`.

## Implementation
- [ ] Adapter updates completed for impacted operations.
- [ ] Runtime/error policy updates completed when required.
- [ ] Test matrix updates completed for impacted packages.
- [ ] Security classification updates completed for new secret/cookie surfaces.

## Verification
- [ ] Required CI gates pass (Doc 07 + Doc 08).
- [ ] High-risk drift items include regression tests.
- [ ] Observability impact reviewed (SLO/alerts/log profile).

## Release
- [ ] Changelog entries include impacted `operation_id` and package.
- [ ] Version bump follows Doc 09 policy.
- [ ] Sync PR reviewed and approved by package owner.
