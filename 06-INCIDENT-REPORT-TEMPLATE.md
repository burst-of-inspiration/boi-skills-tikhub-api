# 06 Incident Report Template

## 1. Incident Metadata
- Incident ID:
- Severity (`P1|P2|P3|P4`):
- Status (`open|mitigated|resolved`):
- Start Time (UTC):
- End Time (UTC):
- Duration:
- Reporter:
- Owner:

## 2. Scope And Impact
- Affected Skill Package(s):
- Affected Operation ID(s):
- Affected Platform(s):
- User Impact Summary:
- Estimated Failed Requests:
- Data Integrity Impact (`none|possible|confirmed`):

## 3. Detection
- Detection Source (`alert|ci|user report|manual`):
- First Alert Time (UTC):
- Error Category:
- Primary Error Signature:
- Correlated Request IDs:

## 4. Timeline
- T0:
- T+:
- T+:
- Resolution Time:

## 5. Root Cause Analysis
- Direct Cause:
- Contributing Factors:
- Why Existing Guards Failed:
- Why It Was Not Detected Earlier:

## 6. Mitigation And Recovery
- Immediate Mitigation Applied:
- Rollback/Hotfix Details:
- Verification Steps:
- Recovery Confirmation:

## 7. Corrective Actions
- Code Fix:
- Test Additions:
- Monitoring/Alert Changes:
- Documentation Updates:
- Owner + ETA Per Action:

## 8. Prevention Checklist
- [ ] Similar endpoints audited
- [ ] Retry/timeout policy verified
- [ ] Error mapping table updated
- [ ] Contract tests updated
- [ ] Runbook updated

## 9. Appendix
- Related PR/Commit:
- Logs (redacted):
- Reproduction Steps:
- Additional Notes:
