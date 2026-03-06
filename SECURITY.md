# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| `v0.1.x-alpha` | yes |
| `< v0.1.0-alpha.1` | no |

## Reporting A Vulnerability
If you discover a security issue:
1. Do not open a public GitHub issue.
2. Send a private report to the repository maintainer.
3. Include:
   - impact summary
   - reproduction steps
   - affected files or workflows
   - suggested mitigation (if available)

Expected response targets:
- Initial acknowledgement: within 72 hours
- Triage decision: within 7 days
- Patch target: based on severity and exploitability

## Scope
This policy covers:
- repository scripts and generation workflow
- secret handling and redaction practices
- contribution and release process security

Out of scope:
- TikHub upstream infrastructure vulnerabilities
- third-party services not operated by this project

## Secret Handling Rules
- Never commit `TIKHUB_API_KEY` or cookie/session secrets.
- Never publish raw sensitive request/response payloads.
- Follow redaction and retention rules in `08-SECURITY-AND-COMPLIANCE.md`.

## Disclosure Policy
- Coordinated disclosure is preferred.
- Public advisory may be published after fix release and maintainer confirmation.
