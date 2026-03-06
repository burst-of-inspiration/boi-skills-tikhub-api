# Contributing

Thanks for contributing to `boi-skills-tikhub-api`.

This project uses a governance-first workflow. Before opening a PR, read:
- `12-CONTRIBUTING-GUIDE.md`
- `12-PR-CHECKLIST.md`
- `12-CODE-REVIEW-CHECKLIST.md`

## Quick Rules
1. Keep changes scoped and reproducible.
2. Regenerate affected CSV artifacts when behavior/contracts change.
3. Follow security and redaction rules from `08-SECURITY-AND-COMPLIANCE.md`.
4. Provide test and validation evidence in PR description.
5. Use Conventional Commits and clear PR titles.

## Development Workflow
1. Create an issue for non-trivial work.
2. Create a branch from `main`.
3. Implement and run required generator/check scripts.
4. Fill PR checklist (`12-PR-CHECKLIST.md`).
5. Request maintainer review.

## OpenAPI Sync Contributions
For schema drift work:
1. Generate sync indexes via `scripts/generate_openapi_sync_indexes.sh`.
2. Run drift comparison via `scripts/diff_openapi_signatures.sh`.
3. Attach drift summary to your PR.

## Security Reporting
Do not open public issues for sensitive vulnerabilities.
Report privately as described in `SECURITY.md`.
