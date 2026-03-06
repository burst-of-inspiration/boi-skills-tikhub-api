# boi-skills-tikhub-api

Open-source repository for packaging TikHub APIs into OpenClaw-compatible skills.

Public repository:
- `https://github.com/burst-of-inspiration/boi-skills-tikhub-api.git`

## Project Goal
Build a full-coverage TikHub skill set with explicit standards for:
- API mapping
- auth and runtime policy
- request/response normalization
- error model and incident handling
- testing, security, release, and observability governance

## Current Release Status
- Current maturity: `v0.1.0-alpha.4` (governance baseline + installer ready)
- Governance documents `01-12`: completed
- Runtime/adapter implementation: in progress

## OpenClaw Quick Install (No Clone)

The installer is OpenClaw/Codex-first:
- auto-detects skills directory (`$OPENCLAW_HOME/skills`, `$CODEX_HOME/skills`, `~/.codex/skills`, ...).
- installs skill files to `<skills-dir>/tikhub-api`.
- prompts for `TIKHUB_API_KEY` and writes it to `<skills-dir>/tikhub-api/.env`.

### Interactive Install
```bash
curl -fsSL https://raw.githubusercontent.com/burst-of-inspiration/boi-skills-tikhub-api/main/install.sh | bash
```

### Non-Interactive Install
```bash
curl -fsSL https://raw.githubusercontent.com/burst-of-inspiration/boi-skills-tikhub-api/main/install.sh -o /tmp/boi-tikhub-install.sh
TIKHUB_API_KEY='your_api_key' bash /tmp/boi-tikhub-install.sh --yes --force
```

You can also pin installer source to a ref:
```bash
bash /tmp/boi-tikhub-install.sh --yes --ref v0.1.0-alpha.4
```

## Maintainer Quick Start (Clone-Based)

### 1. Clone
```bash
git clone https://github.com/burst-of-inspiration/boi-skills-tikhub-api.git
cd boi-skills-tikhub-api
```

### 2. Prerequisites
- `bash`
- `curl`
- `jq`
- `awk`, `sort`, `sed`

### 3. Environment
Create local env file:
```bash
cp .env.example .env
```

Core variable:
- `TIKHUB_API_KEY` for authenticated live calls (do not commit secrets)

### 4. Fetch OpenAPI Snapshot
```bash
curl -fsSL https://api.tikhub.io/openapi.json -o /tmp/tikhub-openapi.json
```

### 5. Generate Baseline Indexes
```bash
./scripts/generate_inventory.sh /tmp/tikhub-openapi.json .
./scripts/generate_runtime_indexes.sh /tmp/tikhub-openapi.json .
./scripts/generate_contract_indexes.sh /tmp/tikhub-openapi.json .
./scripts/generate_error_indexes.sh /tmp/tikhub-openapi.json .
./scripts/generate_test_indexes.sh .
./scripts/generate_security_indexes.sh .
./scripts/generate_release_indexes.sh .
./scripts/generate_observability_indexes.sh .
./scripts/generate_openapi_sync_indexes.sh /tmp/tikhub-openapi.json .
```

### 6. Run Drift Comparison (Optional)
```bash
./scripts/diff_openapi_signatures.sh <old_signatures.csv> 11-OPENAPI-OPERATION-SIGNATURES.csv .
```

## Usage Tutorial
This repository currently provides governance and generation tooling. Minimal maintainers workflow:

1. Pull latest OpenAPI snapshot.
2. Regenerate all indexes.
3. Review changed CSV files.
4. Classify OpenAPI drift risk using `11-OPENAPI-CHANGE-RISK-RULES.csv`.
5. Open PR with evidence and checklists.

Key files to inspect after regeneration:
- `02-API-INVENTORY.csv`
- `07-TEST-MATRIX.csv`
- `08-SECURITY-CLASSIFICATION.csv`
- `10-OBSERVABILITY-MATRIX.csv`
- `11-OPENAPI-DRIFT-SUMMARY.csv` (if drift check executed)

## Repository Structure
- `skills/`: skill implementations and `SKILL.md` files
- `scripts/`: generation and drift tooling
- `examples/`: sample prompts and usage examples
- `00-ROADMAP.md` to `12-CONTRIBUTING-GUIDE.md`: governance and execution docs

## Governance Entry Points
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [CHANGELOG.md](CHANGELOG.md)

Detailed checklists:
- `12-PR-CHECKLIST.md`
- `12-CODE-REVIEW-CHECKLIST.md`
- `11-OPENAPI-SYNC-CHECKLIST.md`
- `09-RELEASE-CHECKLIST.md`
- `08-PUBLISH-SECURITY-CHECKLIST.md`

## Publishing Guide (Maintainer)

### Documentation-Only Alpha
```bash
git tag v0.1.0-alpha.4
git push origin v0.1.0-alpha.4
```

### Stable Release (after runtime code is ready)
1. Complete runtime and adapter implementation.
2. Pass test/security/release gates.
3. Update `CHANGELOG.md`.
4. Tag stable version:
```bash
git tag v0.1.0
git push origin v0.1.0
```

## License
MIT. See `LICENSE`.
