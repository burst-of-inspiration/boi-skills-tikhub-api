# 12 PR Checklist

Status: Draft v1.0  
Last Updated: 2026-03-06

## Scope And Context
- [ ] PR scope is linked to issue/task.
- [ ] Impacted package/platform/module listed.
- [ ] Risk level declared (`low|medium|high`).

## Implementation
- [ ] Change follows existing runtime/contract/error/security policies.
- [ ] Related docs updated in same PR when behavior/policy changed.
- [ ] No unrelated refactors mixed in.

## Generated Artifacts
- [ ] Required generator scripts were rerun.
- [ ] Generated CSV diffs are expected and explained.
- [ ] No unexplained drift remains.

## Test And Validation
- [ ] Required tests executed for touched scope.
- [ ] Test commands and result summary added in PR description.
- [ ] Regression tests added for bugfix/incident-related changes.

## Security And Compliance
- [ ] No secrets/tokens/cookies committed.
- [ ] Sensitive samples/logs are redacted.
- [ ] Relevant security checklist items validated.

## Release And Operations Impact
- [ ] Changelog impact is documented when applicable.
- [ ] Breaking changes are explicitly labeled and migration notes included.
- [ ] Observability/runtime impact noted (alerts/SLO/retry/error behavior).

## Review Readiness
- [ ] PR description includes summary, rationale, evidence, rollback note.
- [ ] Reviewer focus points listed (what to check carefully).
- [ ] All CI checks pass or exceptions are documented.
