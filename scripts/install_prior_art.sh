#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE="${REPO_ROOT}/prior-art"
TARGET_DIR="${HOME}/.local/bin"
TARGET="${TARGET_DIR}/prior-art"

mkdir -p "${TARGET_DIR}"
# Replace any existing file/symlink at the target, then install a fresh symlink.
if [ -e "${TARGET}" ] || [ -L "${TARGET}" ]; then
  rm -f "${TARGET}"
fi
ln -s "${SOURCE}" "${TARGET}"

if ! echo "${PATH}" | grep -Fq "${TARGET_DIR}"; then
  echo "Note: ${TARGET_DIR} is not on your PATH. Add it with:" >&2
  echo "  export PATH=\"${TARGET_DIR}:\$PATH\"" >&2
fi

echo "Installed prior-art -> ${TARGET}"
