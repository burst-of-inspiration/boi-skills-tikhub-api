# 09 Release Checklist

## 1. Scope Freeze
- [ ] Release scope is frozen and linked to issues/PRs.
- [ ] Target package versions and bump type are confirmed.

## 2. Quality Gates
- [ ] Unit/contract/integration gates pass.
- [ ] Required coverage thresholds are met.
- [ ] Critical tier operations pass required test suites.

## 3. Security Gates
- [ ] Secret scan passes.
- [ ] Dependency/license scans pass.
- [ ] Security publish checklist is complete.

## 4. Artifact Integrity
- [ ] Generator scripts rerun and no drift remains.
- [ ] CSV indexes are consistent with release content.
- [ ] Release notes include impacted operation IDs or rules.

## 5. Changelog
- [ ] Changelog entry is added using template.
- [ ] Breaking/deprecation items are clearly labeled.
- [ ] Migration guide is present if required.

## 6. Rollout
- [ ] Canary rollout performed for high-risk packages.
- [ ] Observation window completed.
- [ ] Full rollout approved.

## 7. Post Release
- [ ] Tags pushed.
- [ ] Announcement/release notes published.
- [ ] Follow-up tasks and incidents recorded.
