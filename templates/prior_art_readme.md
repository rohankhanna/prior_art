# Prior-Art Log

This directory is the standard repository-local evidence location for the daily Prior-Art Gate.

The gate is **two-level** and **cadence-enforced**:

- a **product-level scan** that answers "do existing tools already do what this repository is for?", refreshed on a speed-class schedule; and
- a **daily work-slice log** that answers "is today's specific change already solved?", which inherits the current product scan.

Before substantive work begins on a local calendar day, the product scan must be current and the day's slice log must exist and name the slice being worked.

## Evidence model

One file per local calendar day: `logs/prior-art/YYYY-MM-DD.md`. It is the only evidence the gate accepts. Do not store prior-art evidence in `feedback/decisions`, and do not centralize it in any shared hub. It belongs inside the repository being worked on.

The daily file carries the product-level scan and one or more work slices together. A `reused` product scan is not a free pass: the checker locates the dated log that performed the real refresh and rejects if that log is missing, is not a real refresh, or is older than the speed class allows. A `reused` chain is rejected because the referenced log must itself say `product_scan: refreshed`.

## Daily file fields

```markdown
# daily-prior-art-check: YYYY-MM-DD

product_scan: refreshed|reused
product_refreshed_on: YYYY-MM-DD
speed: rapid
product_checked:
- NAME — https://example.com — relevance note
product_overlap:
- OVERLAP_NOTE
product_decision_action: adopt|integrate|extend|contribute|narrow-scope|wait|stop|build
product_decision_why: why
product_extension_path: N/A | path
product_rejected_non_build_options: text
product_differentiation:
- text (required when product_decision_action is build)
slices:
- id: <slug>
  kind: mechanical|capability
  scope: what this slice does
  scan: refreshed|reused - why this scan state is valid
  checked:
  - SOURCE_OR_REFERENCE: NOTE
```

- `product_scan`: `refreshed` means this file performs the product-level scan now; `reused` means it inherits a previous refresh named by `product_refreshed_on`.
- `product_refreshed_on`: the local date of the last real product refresh. When `product_scan: refreshed` it must equal this file's own date. When `reused` it names a past date whose daily log must exist, must say `product_scan: refreshed`, must cite an external source, and must be within the speed-class interval.
- `speed`: the repository's speed class; authoritative here.
- `product_checked`: present when `product_scan: refreshed`; must cite at least one external `http(s)://` URL. Prior art that never looks outside is not prior art. The checker validates externality only, not whether the source was read.
- `slices`: one or more named slices, each tiered by `kind` (see below).

The product-level decision fields (`product_decision_action`, `product_decision_why`, `product_extension_path`, `product_rejected_non_build_options`, `product_differentiation`) are operator substance. The checker does not lint them; the operator is responsible for an honest build-versus-buy decision.

## Speed classes and refresh intervals

- `tectonic`: yearly (365 days)
- `snail`: quarterly (90 days)
- `walking`: monthly (30 days)
- `fast`: biweekly (14 days)
- `rapid`: weekly (7 days)
- `lightspeed`: event-driven — no fixed interval. A `reused` product scan is allowed only when every slice in the file is `kind: mechanical`; a `capability` slice requires a same-day `refreshed` scan.

A fresh product-level scan is required immediately, regardless of interval, when repository intent changes, architecture scope changes materially, a large implementation investment is about to begin, publication or release is near, the user asks build-versus-buy, the agent encounters credible overlapping prior art, or the scan is stale for the repository's speed class.

## Slice fields, tiered by kind

- **mechanical** — running an owned tool, a configuration tweak, a typo, a narrow internal change. Required fields: `id`, `kind`, `scope`, `scan`, `checked` (with at least one item). Do not fill product build-versus-buy fields.
- **capability** — introduces a new external capability or scope. Required fields: `id`, `kind`, `scope`, `scan`, `checked` (with at least one item), `overlap` (with at least one item), `decision_action`, `decision_why`, `extension_path`, `rejected_non_build_options`, and `differentiation` when `decision_action: build`.

Decision actions: `adopt`, `integrate`, `extend`, `contribute`, `narrow-scope`, `wait`, `stop`, `build`.

A `mechanical` slice authorizes only its own named scope; it cannot authorize unrelated capability work. The checker validates every slice in the file.

## Anti-build posture

Treat LLM pro-build bias as a known failure mode. The fact that an LLM can implement something is not evidence that it should be built. Prefer `adopt`, `integrate`, `extend`, `contribute`, `narrow-scope`, `wait`, or `stop` when an existing or emerging project can satisfy the intended outcome with acceptable tradeoffs. A `build` decision must explicitly reject the credible non-build options and state differentiation.

## Checker

`scripts/prior_art_check_gate.sh [repo_path]` validates, for today's `logs/prior-art/YYYY-MM-DD.md`:

- the file exists and has singular `product_scan`, `product_refreshed_on`, and `speed` keys;
- `product_scan` is `refreshed` or `reused` and `speed` is a valid class;
- when `refreshed`: `product_refreshed_on` equals today and `product_checked` cites at least one external `http(s)://` URL;
- when `reused`: `product_refreshed_on` is not today or future, the referenced refresh log exists, says `product_scan: refreshed`, cites an external URL, and (except `lightspeed`) is within the speed-class interval;
- `lightspeed` with a `reused` scan is rejected when any slice is `kind: capability`;
- every slice is well-formed for its `kind` (mechanical minimal set; capability full build-versus-buy set, with `differentiation` when `decision_action: build`);
- no future-dated `product_refreshed_on`, no duplicate top-level keys, and the sensitive-material `[REDACTED]` heuristic holds.

The gate fails closed. Exit 0 passes with a one-line summary; exit 1 fails with a specific error.

## Secrets

Never include credentials, secrets, tokens, or private keys. Replace sensitive material with `[REDACTED]`.

## Durability

Keep `logs/prior-art/` durable across shutdowns and restarts. Its public, private, and version-control treatment follows the repository's boundary policy for operator logs.
