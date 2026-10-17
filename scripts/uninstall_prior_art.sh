#!/usr/bin/env bash
set -euo pipefail

TARGET="${HOME}/.local/bin/prior-art"
if [ -L "${TARGET}" ] || [ -e "${TARGET}" ]; then
  rm -f "${TARGET}"
  echo "Removed ${TARGET}"
else
  echo "prior-art was not installed at ${TARGET}"
fi
