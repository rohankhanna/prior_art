#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  ${0} [repo_path]

Validates the daily prior-art gate for the given repository (defaults to
the current directory). Checks today's logs/prior-art/YYYY-MM-DD.md:

  - product_scan, product_refreshed_on, and speed are present and singular;
  - when product_scan is refreshed: product_refreshed_on is today and
    product_checked cites at least one external http(s):// URL;
  - when product_scan is reused: the referenced refresh log exists, says
    product_scan: refreshed, cites an external URL, and (except lightspeed)
    is within the speed-class interval; a reused chain is rejected;
  - speed is a valid class; lightspeed rejects a reused scan when any slice
    is a capability slice;
  - every slice is well-formed for its kind (mechanical minimal fields;
    capability full build-vs-buy set, with differentiation when action is
    build);
  - no future-dated product_refreshed_on, no duplicate top-level keys, and
    the sensitive-material heuristic holds.

Exit:
  0 on pass with a one-line summary, 1 on any failure, 2 on usage errors.
EOF
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

REPO_PATH="${1:-$(pwd)}"
if [ ! -d "${REPO_PATH}" ]; then
  echo "Error: repository path does not exist: ${REPO_PATH}" >&2
  exit 2
fi
REPO_PATH="$(cd "${REPO_PATH}" && pwd)"
TODAY="$(date +%F)"
PA_DIR="${REPO_PATH}/logs/prior-art"
DAILY="${PA_DIR}/${TODAY}.md"

fail() {
  echo "Error: $1" >&2
  exit 1
}

interval_for_speed() {
  case "$1" in
    tectonic) printf '365' ;;
    snail) printf '90' ;;
    walking) printf '30' ;;
    fast) printf '14' ;;
    rapid) printf '7' ;;
    lightspeed) printf '' ;;
    *) return 1 ;;
  esac
}

# Extract a top-level block from a file: from the header line (regex) until the
# next column-0 non-dash key or EOF. Prints the block body, excluding the
# header line. List items at column 0 ("- ...") and indented lines belong to
# the block; a column-0 "word:" line ends it.
#   $1 = file, $2 = header regex.
extract_block() {
  local file="$1" hdr="$2"
  awk -v hdr="${hdr}" '
    $0 ~ hdr { on=1; next }
    on && /^-/ { print; next }
    on && /^[[:space:]]/ { print; next }
    on && /^$/ { next }
    on { on=0 }
  ' "${file}"
}

# Count column-0 key occurrences. $1 = file, $2 = key.
top_count() {
  local n
  n=$(grep -Ec "^${2}:" "$1") || n=0
  printf '%s' "${n}"
}

# Column-0 scalar value (first match, trimmed). $1 = file, $2 = key.
top_value() {
  grep -E "^${2}:[[:space:]]*" "$1" | head -n1 \
    | sed -E "s/^${2}:[[:space:]]*//; s/[[:space:]]*\$//"
}

# Require a column-0 key exactly once with a non-empty value; prints the value.
require_top() {
  local file="$1" key="$2" cnt val
  cnt=$(top_count "$file" "$key")
  if [ "${cnt}" -eq 0 ]; then
    fail "daily log missing required key: ${key} (${file})"
  fi
  if [ "${cnt}" -gt 1 ]; then
    fail "daily log has duplicate key: ${key} (${file})"
  fi
  val=$(top_value "$file" "$key")
  if [ -z "${val}" ]; then
    fail "daily log key has empty value: ${key} (${file})"
  fi
  printf '%s' "${val}"
}

# Does the product_checked block in $1 cite an external http(s):// URL?
has_external_url() {
  extract_block "$1" '^product_checked:' | grep -qE 'https?://'
}

# Sensitive-material heuristic: sensitive keywords present but no [REDACTED].
sensitive_check() {
  local file="$1" label="$2"
  [ -f "${file}" ] || return 0
  if grep -Eiq "(password|passwd|secret|token|api[_-]?key|private[[:space:]_-]?key|credential)" "${file}" \
     && ! grep -Fq "[REDACTED]" "${file}"; then
    fail "${label} appears to contain sensitive material without [REDACTED]: ${file}"
  fi
}

# --- Daily file -------------------------------------------------------------

if [ ! -f "${DAILY}" ]; then
  fail "missing daily prior-art log: ${DAILY}"
fi

PRODUCT_SCAN=$(require_top "${DAILY}" product_scan | awk '{print $1}')
case "${PRODUCT_SCAN}" in
  refreshed|reused) ;;
  *) fail "product_scan must be 'refreshed' or 'reused' (got: ${PRODUCT_SCAN})" ;;
esac

PRODUCT_REFRESHED=$(require_top "${DAILY}" product_refreshed_on)
SPEED=$(require_top "${DAILY}" speed)
if ! printf '%s\n' tectonic snail walking fast rapid lightspeed | grep -Fxq "${SPEED}"; then
  fail "speed invalid: ${SPEED} (must be one of tectonic, snail, walking, fast, rapid, lightspeed)"
fi

printf '%s' "${PRODUCT_REFRESHED}" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
  || fail "product_refreshed_on must be YYYY-MM-DD (got: ${PRODUCT_REFRESHED})"

if [[ "${PRODUCT_REFRESHED}" > "${TODAY}" ]]; then
  fail "product_refreshed_on is in the future: ${PRODUCT_REFRESHED} (today is ${TODAY})"
fi

# --- product_scan semantics ------------------------------------------------

if [ "${PRODUCT_SCAN}" = "refreshed" ]; then
  if [ "${PRODUCT_REFRESHED}" != "${TODAY}" ]; then
    fail "product_scan is refreshed but product_refreshed_on='${PRODUCT_REFRESHED}' != today '${TODAY}'"
  fi
  has_external_url "${DAILY}" \
    || fail "refreshed product scan must cite at least one external http(s):// URL in product_checked (${DAILY})"
else
  if [ "${PRODUCT_REFRESHED}" = "${TODAY}" ]; then
    fail "product_scan is reused but product_refreshed_on is today; refresh or correct the date"
  fi
  REFRESH_LOG="${PA_DIR}/${PRODUCT_REFRESHED}.md"
  if [ ! -f "${REFRESH_LOG}" ]; then
    fail "reused product_refreshed_on='${PRODUCT_REFRESHED}' but referenced log not found: ${REFRESH_LOG}"
  fi
  grep -qE '^product_scan:[[:space:]]*refreshed' "${REFRESH_LOG}" \
    || fail "referenced refresh log is not a real refresh (product_scan != refreshed): ${REFRESH_LOG}"
  has_external_url "${REFRESH_LOG}" \
    || fail "referenced refresh log has no external http(s):// URL in product_checked: ${REFRESH_LOG}"
  if [ "${SPEED}" != "lightspeed" ]; then
    INTERVAL=$(interval_for_speed "${SPEED}") || fail "internal error: no interval for speed ${SPEED}"
    PAST_S=$(date -d "${PRODUCT_REFRESHED}" +%s) || fail "could not parse date: ${PRODUCT_REFRESHED}"
    TODAY_S=$(date -d "${TODAY}" +%s)
    AGE=$(( (TODAY_S - PAST_S) / 86400 ))
    if [ "${AGE}" -gt "${INTERVAL}" ]; then
      fail "product scan overdue: last refresh ${PRODUCT_REFRESHED}, age ${AGE} days exceeds ${SPEED} interval ${INTERVAL} days"
    fi
  fi
fi

# --- slices ----------------------------------------------------------------

WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

SLICES_BLOCK="${WORKDIR}/slices.block"
extract_block "${DAILY}" '^slices:' > "${SLICES_BLOCK}" || true
if [ ! -s "${SLICES_BLOCK}" ]; then
  fail "daily log has no slices block: ${DAILY}"
fi

SLICE_IDS=$(grep -E '^- id:[[:space:]]+' "${SLICES_BLOCK}" \
  | sed -E 's/^- id:[[:space:]]+//; s/[[:space:]]*$//') || SLICE_IDS=""
if [ -z "${SLICE_IDS}" ]; then
  fail "slices block has no slice entries"
fi

# Extract one slice's text block by id (from its "- id:" line to the next).
extract_slice() {
  local slug="$1"
  awk -v slug="${slug}" '
    /^- id:[[:space:]]+/ {
      thisid=$0; sub(/^- id:[[:space:]]+/, "", thisid); gsub(/[[:space:]]*$/, "", thisid)
      if (inblock) exit
      if (thisid == slug) { inblock=1; print; next }
      next
    }
    inblock { print }
  ' "${SLICES_BLOCK}"
}

# Does a list field have at least one "  - " item? $1 = slice file, $2 = key.
list_has_items() {
  awk -v k="$2" '
    $0 == "  " k ":" { on=1; next }
    on && /^  - / { found=1; exit }
    on && /^  [A-Za-z_][A-Za-z0-9_]*:/ { exit }
    END { exit !found }
  ' "$1"
}

validate_slice() {
  local slug="$1"
  local sf="${WORKDIR}/slice.txt"
  extract_slice "${slug}" > "${sf}" || true
  if [ ! -s "${sf}" ]; then
    fail "slice block is empty for id: ${slug}"
  fi

  local kind
  kind=$(grep -E '^  kind:[[:space:]]+' "${sf}" | head -n1 \
    | sed -E 's/^  kind:[[:space:]]+//; s/[[:space:]]*$//') || kind=""
  if [ -z "${kind}" ]; then
    fail "slice '${slug}' missing kind"
  fi
  case "${kind}" in
    mechanical|capability) ;;
    *) fail "slice '${slug}' has invalid kind: ${kind}" ;;
  esac

  local f
  for f in scope scan; do
    grep -Eq "^  ${f}:" "${sf}" || fail "slice '${slug}' (kind=${kind}) missing required field: ${f}"
  done
  grep -q '^  checked:' "${sf}" || fail "slice '${slug}' (kind=${kind}) missing required field: checked"
  list_has_items "${sf}" checked || fail "slice '${slug}' (kind=${kind}) field checked has no items"

  if [ "${kind}" = "capability" ]; then
    grep -q '^  overlap:' "${sf}" || fail "slice '${slug}' (capability) missing required field: overlap"
    list_has_items "${sf}" overlap || fail "slice '${slug}' (capability) field overlap has no items"
    for f in decision_action decision_why extension_path rejected_non_build_options; do
      grep -Eq "^  ${f}:" "${sf}" || fail "slice '${slug}' (capability) missing required field: ${f}"
    done
    local sact
    sact=$(grep -E '^  decision_action:[[:space:]]+' "${sf}" | head -n1 \
      | sed -E 's/^  decision_action:[[:space:]]+//; s/[[:space:]]*$//') || sact=""
    if [ -z "${sact}" ]; then
      fail "slice '${slug}' (capability) decision_action is empty"
    fi
    case "${sact}" in
      adopt|integrate|extend|contribute|narrow-scope|wait|stop|build) ;;
      *) fail "slice '${slug}' (capability) decision_action invalid: ${sact}" ;;
    esac
    if [ "${sact}" = "build" ]; then
      grep -Eq '^  differentiation:' "${sf}" \
        || fail "slice '${slug}' (capability) action build requires differentiation"
    fi
    if [ "${SPEED}" = "lightspeed" ] && [ "${PRODUCT_SCAN}" = "reused" ]; then
      fail "lightspeed capability slice '${slug}' requires a same-day refreshed scan (product_scan is reused)"
    fi
  fi

  printf '%s' "${kind}"
}

SUMMARY=""
while IFS= read -r sid; do
  [ -z "${sid}" ] && continue
  skind=$(validate_slice "${sid}")
  SUMMARY+="${sid}(${skind}) "
done <<EOF
${SLICE_IDS}
EOF

# --- sensitive material ----------------------------------------------------

sensitive_check "${DAILY}" "daily slice log"

echo "Prior-art gate satisfied: date=${TODAY} speed=${SPEED} product_scan=${PRODUCT_SCAN} slices=${SUMMARY% }"
exit 0