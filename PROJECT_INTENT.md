# PROJECT INTENT

## Purpose

Provide a single, installable command-line tool that applies a managed prior-art directive block to any repository's agent instruction files, so the daily prior-art gate is in force before LLM-enhanced work begins.

## Intended Outcome

Running `prior-art apply <repo>` is sufficient to enroll a repository in prior-art governance: the managed block, the gate contract, and the fail-closed checker are installed, and instruction mirrors are synced. No manual copying of rules is required.

## Notes

- This tool is self-contained and does not depend on piecrust, retcon, feedback-hub, chug, terminable, or publicist. Its managed block is a sibling region to theirs and coexists without conflict.
- The canonical contract lives in `templates/prior_art_readme.md`, installed into target repositories as `logs/prior-art/README.md`.
