# 12 Code Review Checklist

Status: Draft v1.0  
Last Updated: 2026-03-06

## Correctness
- [ ] Behavior matches issue and PR summary.
- [ ] Edge cases and failure paths are handled.
- [ ] Changes do not silently break existing contract assumptions.

## Contract And Runtime Policy
- [ ] Request/response handling aligns with Doc 05.
- [ ] Retry/timeout/rate-limit logic aligns with Doc 03.
- [ ] Error classification and envelopes align with Doc 06.

## Security
- [ ] No plaintext secrets or sensitive identifiers leaked.
- [ ] Redaction policy aligns with Doc 08.
- [ ] New secret/cookie surfaces are reflected in security artifacts if needed.

## Tests And Evidence
- [ ] Test evidence is sufficient for risk tier.
- [ ] Critical/high-risk changes include regression coverage.
- [ ] Generated outputs are reproducible and consistent.

## Observability And Operations
- [ ] Logging fields and redaction profile are appropriate.
- [ ] Alert/SLO implications are acknowledged for high-risk changes.
- [ ] Incident or rollback notes are present for risky changes.

## Maintainability
- [ ] Scope is focused and readable.
- [ ] Naming and structure are clear.
- [ ] Docs/checklists/changelog updates are included where needed.

## Review Decision
- [ ] Approve
- [ ] Request changes
- [ ] Block (policy/security/regression risk)
