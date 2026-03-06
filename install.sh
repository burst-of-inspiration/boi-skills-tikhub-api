#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="burst-of-inspiration"
REPO_NAME="boi-skills-tikhub-api"
SKILL_NAME="tikhub-api"
REPO_REF="main"
FORCE="false"
ASSUME_YES="false"
SKILLS_DIR=""
INPUT_API_KEY="${TIKHUB_API_KEY:-}"

usage() {
  cat <<USAGE
Usage: install.sh [options]

Install TikHub skill into OpenClaw/Codex skills directory.

Options:
  --skill-dir <path>   Install into a specific skills directory.
  --api-key <key>      Provide TikHub API key directly.
  --ref <git_ref>      Git ref for remote archive source (default: main).
  --force              Overwrite existing installed skill directory.
  --yes                Non-interactive mode.
  -h, --help           Show this help message.
USAGE
}

log() {
  printf '[install] %s\n' "$*" >&2
}

err() {
  printf '[install][error] %s\n' "$*" >&2
}

can_use_tty() {
  [[ -t 0 || -t 1 || -t 2 ]] && [[ -r /dev/tty ]]
}

prompt() {
  local message="$1"
  local default_value="${2:-}"
  local answer=""

  if [[ "$ASSUME_YES" == "true" ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  if [[ -n "$default_value" ]]; then
    if can_use_tty; then
      read -r -p "$message [$default_value]: " answer < /dev/tty || true
    else
      read -r -p "$message [$default_value]: " answer || true
    fi
    if [[ -z "$answer" ]]; then
      answer="$default_value"
    fi
  else
    if can_use_tty; then
      read -r -p "$message: " answer < /dev/tty || true
    else
      read -r -p "$message: " answer || true
    fi
  fi

  printf '%s\n' "$answer"
}

confirm() {
  local message="$1"

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi

  local ans
  if can_use_tty; then
    read -r -p "$message [y/N]: " ans < /dev/tty || true
  else
    read -r -p "$message [y/N]: " ans || true
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

set_env_kv() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file
  tmp_file="$(mktemp)"

  awk -v k="$key" -v v="$value" '
    BEGIN { updated=0 }
    $0 ~ "^" k "=" {
      print k "=" v
      updated=1
      next
    }
    { print }
    END {
      if (updated==0) {
        print k "=" v
      }
    }
  ' "$file" > "$tmp_file"

  mv "$tmp_file" "$file"
}

detect_skills_dir() {
  local candidates=()

  if [[ -n "${SKILLS_DIR}" ]]; then
    printf '%s\n' "$SKILLS_DIR"
    return 0
  fi

  if [[ -n "${OPENCLAW_HOME:-}" ]]; then
    candidates+=("$OPENCLAW_HOME/skills")
  fi

  if [[ -n "${CODEX_HOME:-}" ]]; then
    candidates+=("$CODEX_HOME/skills")
  fi

  candidates+=("$HOME/.codex/skills")
  candidates+=("$HOME/.openclaw/skills")
  candidates+=("$HOME/.config/openclaw/skills")

  local c
  for c in "${candidates[@]}"; do
    if [[ -d "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done

  printf '%s\n' "$HOME/.codex/skills"
}

resolve_source_root() {
  local script_dir
  local script_source="${BASH_SOURCE[0]-$0}"
  script_dir="$(cd "$(dirname "$script_source")" && pwd)"

  if [[ -f "$script_dir/skills/tikhub/SKILL.md" ]]; then
    printf '%s\n' "$script_dir"
    return 0
  fi

  if [[ -f "./skills/tikhub/SKILL.md" ]]; then
    printf '%s\n' "$(pwd)"
    return 0
  fi

  local tmp_dir archive_url extracted_root
  tmp_dir="$(mktemp -d)"
  archive_url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REPO_REF}"

  log "Local repository files not found, downloading ${REPO_OWNER}/${REPO_NAME}@${REPO_REF}"
  curl -fsSL "$archive_url" | tar -xz -C "$tmp_dir"

  extracted_root="$(find "$tmp_dir" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)"
  if [[ -z "$extracted_root" || ! -f "$extracted_root/skills/tikhub/SKILL.md" ]]; then
    err "Failed to resolve skill source from downloaded archive"
    exit 1
  fi

  printf '%s\n' "$extracted_root"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)
      [[ $# -lt 2 ]] && { err "--skill-dir requires a path"; exit 1; }
      SKILLS_DIR="$2"
      shift 2
      ;;
    --api-key)
      [[ $# -lt 2 ]] && { err "--api-key requires a value"; exit 1; }
      INPUT_API_KEY="$2"
      shift 2
      ;;
    --ref)
      [[ $# -lt 2 ]] && { err "--ref requires a value"; exit 1; }
      REPO_REF="$2"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --yes)
      ASSUME_YES="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

TARGET_SKILLS_DIR="$(detect_skills_dir)"
if [[ "$ASSUME_YES" != "true" ]]; then
  TARGET_SKILLS_DIR="$(prompt "OpenClaw/Codex skills directory" "$TARGET_SKILLS_DIR")"
fi

if [[ -z "$TARGET_SKILLS_DIR" ]]; then
  err "Skills directory is empty"
  exit 1
fi

mkdir -p "$TARGET_SKILLS_DIR"
TARGET_SKILL_DIR="$TARGET_SKILLS_DIR/$SKILL_NAME"

SOURCE_ROOT="$(resolve_source_root | tail -n 1)"
SOURCE_SKILL_DIR="$SOURCE_ROOT/skills/tikhub"
SOURCE_ENV_EXAMPLE="$SOURCE_ROOT/.env.example"

if [[ ! -f "$SOURCE_SKILL_DIR/SKILL.md" ]]; then
  err "Skill source missing: $SOURCE_SKILL_DIR/SKILL.md"
  exit 1
fi

if [[ -d "$TARGET_SKILL_DIR" ]]; then
  if [[ "$FORCE" != "true" ]]; then
    if ! confirm "Skill already exists at $TARGET_SKILL_DIR. Overwrite?"; then
      err "Installation cancelled by user"
      exit 1
    fi
  fi
  rm -rf "$TARGET_SKILL_DIR"
fi

mkdir -p "$TARGET_SKILL_DIR"
cp -R "$SOURCE_SKILL_DIR"/. "$TARGET_SKILL_DIR"/

ENV_FILE="$TARGET_SKILL_DIR/.env"
if [[ -f "$SOURCE_ENV_EXAMPLE" ]]; then
  cp "$SOURCE_ENV_EXAMPLE" "$ENV_FILE"
else
  cat > "$ENV_FILE" <<ENV
TIKHUB_API_KEY=
TIKHUB_BASE_URL=https://api.tikhub.io
TIKHUB_TIMEOUT_MS=30000
TIKHUB_MAX_RETRIES=3
ENV
fi

if [[ -z "$INPUT_API_KEY" ]]; then
  if [[ "$ASSUME_YES" == "true" ]]; then
    err "TIKHUB_API_KEY not provided in non-interactive mode"
    err "Set env TIKHUB_API_KEY or use --api-key"
    exit 1
  fi

  if can_use_tty; then
    read -r -s -p "Enter TIKHUB_API_KEY (input hidden): " INPUT_API_KEY < /dev/tty
    printf '\n' > /dev/tty
  else
    err "No interactive TTY available for API key prompt"
    err "Set env TIKHUB_API_KEY or use --api-key/--yes"
    exit 1
  fi

  if [[ -z "$INPUT_API_KEY" ]]; then
    err "TIKHUB_API_KEY cannot be empty"
    exit 1
  fi
fi

set_env_kv "$ENV_FILE" "TIKHUB_API_KEY" "$INPUT_API_KEY"
chmod 600 "$ENV_FILE"

log "Installed skill: $TARGET_SKILL_DIR"
log "API key saved to: $ENV_FILE"
log "Done. Restart your OpenClaw/Codex session if skills are cached."
