# 10 Operations Runbook

Status: Draft v1.0  
Last Updated: 2026-03-06

## 1. Purpose
Provide a deterministic operator playbook for alert triage, diagnosis, mitigation, and closure.

## 2. Inputs Required During Triage
- `request_id`
- `operation_id`
- `skill_package`
- `error_category`
- `upstream_http_status`
- recent latency and error-rate metrics

## 3. Triage Sequence
1. Confirm alert severity from `10-ALERT-CATALOG.csv`.
2. Identify blast radius: single operation, package-wide, or cross-package.
3. Check if affected operation is `SLO1` and escalate immediately if yes.
4. Classify incident severity (`P1`/`P2`/`P3`/`P4`) using Doc 06 model.

## 4. Diagnosis Checklist
- Verify auth validity and secret rotation status.
- Check runtime controls: retry, timeout, rate-limit, circuit-open counters.
- Compare error profile vs previous 24h baseline.
- Review recent code/config changes tied to impacted package.
- Validate whether issue is upstream dependency or local adapter/runtime behavior.

## 5. Mitigation Playbook By Category

### 5.1 RATE_LIMITED
- Reduce concurrency and tighten local rate-limit.
- Apply jittered backoff and retry budget enforcement.
- Temporarily reduce non-critical traffic if needed.

### 5.2 TIMEOUT / NETWORK_ERROR / UPSTREAM_5XX
- Confirm upstream health and network route stability.
- Increase timeout only within approved bounds; avoid unlimited waits.
- Enable package-scoped degradation/fallback path if available.

### 5.3 AUTH_ERROR / PERMISSION_ERROR
- Validate credential scope and expiration immediately.
- Rotate compromised credentials.
- Block high-risk calls until auth path is healthy.

### 5.4 CONTRACT_VIOLATION
- Freeze rollout for impacted package.
- Capture redacted raw response sample for parser mismatch analysis.
- Hotfix adapter mapping and add regression tests before re-enable.

## 6. Verification Before Closure
- Error rate and latency return below threshold for at least two windows.
- No new P1/P2 alerts for the same `operation_id`.
- Critical user flows validated on representative operations.
- Incident report draft completed.

## 7. Post-Incident Mandatory Actions
- Fill `06-INCIDENT-REPORT-TEMPLATE.md`.
- Add regression tests as defined in Doc 07.
- Update runtime/error/alert policy docs if root cause reveals policy gap.
- Record follow-up tasks with owner and ETA.

## 8. Ownership
- Primary owner: package maintainer of affected `skill_package`.
- Secondary owner: core runtime maintainer for cross-cutting controls.
- Incident commander required for all P1 and P2 incidents.
