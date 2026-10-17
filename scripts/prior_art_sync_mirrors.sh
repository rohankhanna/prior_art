#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  ${0} [repo_path]

Regenerate exact CLAUDE.md, GEMINI.md, and HERMES.md mirrors of AGENTS.md
in the target repository (defaults to the current directory).
EOF
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 1
fi

PROJECT_REPO_PATH="${1:-$(pwd)}"

if [ ! -d "${PROJECT_REPO_PATH}" ]; then
  echo "Error: project repository path does not exist: ${PROJECT_REPO_PATH}" >&2
  exit 1
fi

PROJECT_REPO_PATH="$(cd "${PROJECT_REPO_PATH}" && pwd)"
CANONICAL_FILE="${PROJECT_REPO_PATH}/AGENTS.md"
INSTRUCTION_MIRRORS=(
  "${PROJECT_REPO_PATH}/CLAUDE.md"
  "${PROJECT_REPO_PATH}/GEMINI.md"
  "${PROJECT_REPO_PATH}/HERMES.md"
)

if [ ! -f "${CANONICAL_FILE}" ]; then
  echo "Error: canonical instruction file not found: ${CANONICAL_FILE}" >&2
  exit 1
fi

for mirror_file in "${INSTRUCTION_MIRRORS[@]}"; do
  rm -f "${mirror_file}"
  cp "${CANONICAL_FILE}" "${mirror_file}"
  echo "${mirror_file}"
done
