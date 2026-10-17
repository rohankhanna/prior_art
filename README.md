# prior-art

A single command-line tool that installs a managed **Prior-Art Directive** block into any repository's `AGENTS.md` (and its `CLAUDE.md`, `GEMINI.md`, `HERMES.md` mirrors) so that before LLM-enhanced work begins, the daily prior-art gate is in force.

## Why

Before starting LLM-enhanced work on a repository, you want the same prior-art discipline applied everywhere: a two-level, cadence-enforced gate (product-level scan + daily work-slice log) with a fail-closed checker. Instead of copying rules by hand into every repository's `AGENTS.md`, run one command.

## Install

Clone the repository, then run the built-in installer:

```bash
git clone https://github.com/rohankhanna/prior_art.git
cd prior_art
./prior-art install
```

This symlinks `prior-art` into `~/.local/bin`. Ensure `~/.local/bin` is on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to your shell profile if needed).

To remove it later:

```bash
prior-art uninstall
```

## Usage

`apply` and `check` target the **current directory by default**. Run them from inside the repository you want to govern:

```bash
cd /path/to/your-repo

# Apply the managed block + contract + checker to this repository
prior-art apply

# Validate the daily prior-art gate for this repository
prior-art check

# Help
prior-art help
```

You may also pass an absolute repository path explicitly instead of `cd`-ing into it:

```bash
prior-art apply /path/to/your-repo
prior-art check /path/to/your-repo
```

`apply` is idempotent. It:

1. Creates or refreshes the `<!-- prior-art:managed:start --> ... <!-- prior-art:managed:end -->` block in `AGENTS.md` without disturbing adjacent managed regions installed by other appliers.
2. Installs `logs/prior-art/README.md` (the gate contract).
3. Installs `scripts/prior_art_check_gate.sh` (the fail-closed checker).
4. Regenerates exact `CLAUDE.md`, `GEMINI.md`, and `HERMES.md` mirrors of `AGENTS.md`.

## What the block enforces

See `templates/prior_art_readme.md` for the full contract. In summary:

- Before substantive work, satisfy the daily Prior-Art Gate.
- Evidence is one file per local calendar day: `logs/prior-art/YYYY-MM-DD.md`.
- A `refreshed` product scan cites at least one external `http(s)://` URL.
- Speed classes: `tectonic`, `snail`, `walking`, `fast`, `rapid`, `lightspeed`.
- Slice kinds: `mechanical` (minimal) and `capability` (full build-versus-buy set).
- Anti-build posture: prefer adopt/integrate/extend/contribute/narrow-scope/wait/stop over build.
- Never include secrets; use `[REDACTED]`.
- The gate fails closed.
