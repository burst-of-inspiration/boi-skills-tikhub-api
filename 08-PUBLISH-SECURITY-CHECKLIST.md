# 08 Publish Security Checklist

## 1. Secrets
- [ ] No hardcoded `TIKHUB_API_KEY` or token-like strings in repo.
- [ ] `.env` and secret files are excluded by `.gitignore`.
- [ ] Recent commit diff passes secret scan.

## 2. Logging And Redaction
- [ ] Redaction tests for `Authorization`, `cookie`, API keys pass.
- [ ] No raw cookie-bearing request body is logged.
- [ ] Incident/log attachments are redacted.

## 3. Data Safety
- [ ] Fixtures contain only synthetic or sanitized data.
- [ ] No private media assets committed.
- [ ] No unintended cache/output artifacts committed.

## 4. Dependencies And Licenses
- [ ] Dependency vulnerability scan is within policy threshold.
- [ ] License scan passes allowlist policy.
- [ ] Newly added dependencies were reviewed and justified.

## 5. Security Matrix Consistency
- [ ] `08-SECURITY-CLASSIFICATION.csv` regenerated cleanly.
- [ ] `08-SECURITY-SUMMARY-BY-RISK.csv` regenerated cleanly.
- [ ] Critical/high-risk operations have assigned test coverage.

## 6. Release Decision
- [ ] Security reviewer sign-off complete.
- [ ] Any open security exceptions are documented with expiry date.
- [ ] Release approved for publication.
