#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  ${0} [repo_path]

Run with no argument to target the current directory.
You may also pass one absolute repo path as the only argument.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRIOR_ART_README_SOURCE="${REPO_ROOT}/templates/prior_art_readme.md"
CHECKER_SOURCE="${SCRIPT_DIR}/prior_art_check_gate.sh"
MIRROR_SYNC="${SCRIPT_DIR}/prior_art_sync_mirrors.sh"
PROJECT_REPO_PATH="$(cd "${PROJECT_REPO_PATH}" && pwd)"

for required_file in \
  "${PRIOR_ART_README_SOURCE}" \
  "${CHECKER_SOURCE}" \
  "${MIRROR_SYNC}"; do
  if [ ! -f "${required_file}" ]; then
    echo "Error: required prior-art file not found: ${required_file}" >&2
    exit 1
  fi
done

START_MARKER="<!-- prior-art:managed:start -->"
END_MARKER="<!-- prior-art:managed:end -->"
CANONICAL_FILE="${PROJECT_REPO_PATH}/AGENTS.md"

ensure_file() {
  local path="$1"
  local default_heading="$2"
  if [ ! -f "${path}" ]; then
    printf "# %s\n" "${default_heading}" > "${path}"
  fi
}

upsert_managed_block() {
  local target_file="$1"
  local block_file prefix_file suffix_file tmp_file normalized_file

  block_file="$(mktemp)"
  cat > "${block_file}" <<BLOCK_EOF

${START_MARKER}
## Prior-Art Directive (Managed)

- Before substantive work, satisfy the daily Prior-Art Gate. The gate is two-level and cadence-enforced: a product-level scan that answers "do existing tools already do what this repository is for?" refreshed on a speed-class schedule, and a daily work-slice log that answers "is today's specific change already solved?" which inherits the current product scan.
- The gate contract lives in \`logs/prior-art/README.md\`; do not duplicate that contract here. Treat it as the canonical source of truth for evidence format, speed classes, slice kinds, and the checker semantics.
- Accepted evidence is today's daily log (\`logs/prior-art/YYYY-MM-DD.md\`) naming the last real product-level refresh date and the worked slice. One file per local calendar day is the only evidence the gate accepts. Do not store prior-art evidence in feedback artifacts or any shared hub; it belongs inside this repository.
- Run \`scripts/prior_art_check_gate.sh\` before substantive work. The gate fails closed: exit 0 passes with a one-line summary, exit 1 fails with a specific error. Do not manufacture freshness or mark a scan current without a real external check.
- A \`refreshed\` product scan must cite at least one external \`http(s)://\` URL in \`product_checked\`. Prior art that never looks outside the repository is not prior art. A \`reused\` scan must name a past date whose own log says \`product_scan: refreshed\`, cites an external URL, and is within the speed-class interval; a reused chain is rejected.
- Speed classes and refresh intervals: \`tectonic\` yearly (365 days), \`snail\` quarterly (90 days), \`walking\` monthly (30 days), \`fast\` biweekly (14 days), \`rapid\` weekly (7 days), \`lightspeed\` event-driven. A \`lightspeed\` repository rejects a reused scan when any slice is \`kind: capability\`; a capability slice requires a same-day refreshed scan.
- Slice kinds are tiered: \`mechanical\` (running an owned tool, a configuration tweak, a typo, a narrow internal change) needs the minimal field set; \`capability\` (introduces a new external capability or scope) needs the full build-versus-buy set including overlap, decision action, why, extension path, rejected non-build options, and differentiation when the action is \`build\`. A mechanical slice authorizes only its own named scope.
- Decision actions: \`adopt\`, \`integrate\`, \`extend\`, \`contribute\`, \`narrow-scope\`, \`wait\`, \`stop\`, \`build\`.
- Hold an anti-build posture. Treat LLM pro-build bias as a known failure mode: the fact that an LLM can implement something is not evidence that it should be built. Prefer \`adopt\`, \`integrate\`, \`extend\`, \`contribute\`, \`narrow-scope\`, \`wait\`, or \`stop\` when an existing or emerging project can satisfy the intended outcome with acceptable tradeoffs. A \`build\` decision must explicitly reject the credible non-build options and state differentiation.
- A fresh product-level scan is required immediately, regardless of interval, when repository intent changes, architecture scope changes materially, a large implementation investment is about to begin, publication or release is near, the user asks build-versus-buy, the agent encounters credible overlapping prior art, or the scan is stale for the repository's speed class.
- Never include credentials, secrets, tokens, or private keys in a prior-art log. Replace sensitive material with \`[REDACTED]\`. The checker rejects sensitive keywords present without \`[REDACTED]\`.
- Keep \`logs/prior-art/\` durable across shutdowns and restarts; persist the daily logs to disk and support safe resume after reboot.
- Treat repo-local \`AGENTS.md\` as canonical when \`CLAUDE.md\`, \`GEMINI.md\`, or \`HERMES.md\` mirrors exist. Keep those mirrors as exact plain-file replicas of \`AGENTS.md\`. Do not make intended instruction changes directly in the mirrors; apply them to \`AGENTS.md\` and regenerate mirrors from it.
- Do not duplicate this managed block or the prior-art contract into other instruction surfaces. \`prior-art apply\` installs and refreshes this block; \`prior-art check\` validates the gate. This block is a sibling managed region to blocks installed by other appliers (feedback-hub, piecrust, retcon, chug, terminable, publicist); re-running \`prior-art apply\` refreshes only this region and does not disturb adjacent managed regions.
- Do not remove this managed block to bypass the gate. If the repository is not currently subject to prior-art governance, leave the block installed and simply do not run the checker; removing the block does not remove the obligation when it is in force.
${END_MARKER}
BLOCK_EOF

  tmp_file="$(mktemp)"
  if grep -qx -- "${START_MARKER}" "${target_file}" 2>/dev/null; then
    prefix_file="$(mktemp)"
    awk -v start="${START_MARKER}" '$0 == start { exit } { print }' "${target_file}" > "${prefix_file}"
    suffix_file="$(mktemp)"
    awk -v end="${END_MARKER}" 'BEGIN { seen = 0 } seen { print; next } $0 == end { seen = 1; next }' "${target_file}" > "${suffix_file}"
    cat "${prefix_file}" "${block_file}" "${suffix_file}" > "${tmp_file}"
    rm -f "${prefix_file}" "${suffix_file}"
  else
    if [ -s "${target_file}" ]; then
      cp "${target_file}" "${tmp_file}"
    fi
    cat "${block_file}" >> "${tmp_file}"
  fi

  normalized_file="$(mktemp)"
  awk '
    BEGIN { started = 0; pending_blank = 0 }
    /^[[:space:]]*$/ {
      if (started) {
        pending_blank = 1
      }
      next
    }
    {
      if (started && pending_blank) {
        print ""
      }
      print
      started = 1
      pending_blank = 0
    }
  ' "${tmp_file}" > "${normalized_file}"

  mv "${normalized_file}" "${target_file}"
  rm -f "${block_file}" "${tmp_file}"
}

install_prior_art_guidance() {
  local repo_dir="$1"
  local prior_art_dir="${repo_dir}/logs/prior-art"
  local scripts_dir="${repo_dir}/scripts"
  local readme_target="${prior_art_dir}/README.md"
  local checker_target="${scripts_dir}/prior_art_check_gate.sh"

  mkdir -p "${prior_art_dir}" "${scripts_dir}"
  if [ "$(readlink -f "${PRIOR_ART_README_SOURCE}")" != "$(readlink -f "${readme_target}" 2>/dev/null || printf '%s' "${readme_target}")" ]; then
    cp "${PRIOR_ART_README_SOURCE}" "${readme_target}"
  fi
  if [ "$(readlink -f "${CHECKER_SOURCE}")" != "$(readlink -f "${checker_target}" 2>/dev/null || printf '%s' "${checker_target}")" ]; then
    cp "${CHECKER_SOURCE}" "${checker_target}"
  fi
  chmod +x "${checker_target}"
}

ensure_file "${CANONICAL_FILE}" "AGENTS"
upsert_managed_block "${CANONICAL_FILE}"
install_prior_art_guidance "${PROJECT_REPO_PATH}"
"${MIRROR_SYNC}" "${PROJECT_REPO_PATH}"

echo "${CANONICAL_FILE}"
echo "${PROJECT_REPO_PATH}/logs/prior-art/README.md"
echo "${PROJECT_REPO_PATH}/scripts/prior_art_check_gate.sh"
echo "Mirrors synced: CLAUDE.md, GEMINI.md, HERMES.md"
