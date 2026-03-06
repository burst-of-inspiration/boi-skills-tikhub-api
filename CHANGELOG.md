# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]
### Added
- Placeholder for upcoming runtime and adapter implementation changes.

## [0.1.0-alpha.5] - 2026-03-06
### Fixed
- `curl ... | bash` installer mode now reads prompts from `/dev/tty` when available.
- Improved piped-install robustness in Bash stdin execution mode.
- Added clearer error guidance for non-interactive sessions without API key input.

## [0.1.0-alpha.4] - 2026-03-06
### Fixed
- Installer download flow no longer mixes log output into the resolved source path.
- Improved source path capture robustness during remote archive installation.

## [0.1.0-alpha.3] - 2026-03-06
### Fixed
- Updated pinned installer ref example in README from older alpha tag to current series.

## [0.1.0-alpha.2] - 2026-03-06
### Added
- OpenClaw/Codex-first installer script `install.sh`.
- Automatic skill path detection for OpenClaw/Codex environments.
- Interactive and non-interactive API key onboarding with secure `.env` write.
- Root-level OSS governance files: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `RELEASE.md`.
- Expanded `README.md` with no-clone install tutorial and maintainer quick start.

## [0.1.0-alpha.1] - 2026-03-06
### Added
- Initial project scaffold (`README`, `LICENSE`, `.env.example`, scripts, skill directory).
- Governance document set `00-12` for scope, architecture, runtime, contract, error, test, security, release, observability, sync, and contributing.
- OpenAPI-driven generated baselines for inventory, runtime policy, contract profiles, error surfaces, test matrix, security classification, release priorities, observability matrix, and sync signatures.
- Maintainer checklists for release, security, sync, PR review, and contribution workflow.

### Notes
- This is a governance-first alpha release.
- Runtime adapters and production-ready skill handlers are not fully implemented yet.
