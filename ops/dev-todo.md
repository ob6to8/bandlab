# Dev Todo

Development tasks for the tooling and infrastructure. These are NOT band operational todos (those go in `.state/todos.json`).

## Tooling Exploration

- [ ] **gum** — Charm.sh TUI components. `gum choose` would replace bash `select` with arrow-key navigation and fuzzy search. Evaluate whether the dependency is worth the UX improvement.
- [ ] **fzf** — Fuzzy finder. Alternative to gum for interactive selection. More widely installed. Could pipe command list into fzf.
- [ ] **justfile** — Modern command runner. `just --list` auto-documents all commands. Could replace the `bandlab` entry script entirely. Evaluate syntax and whether it fits the workflow model.

## Index Generation

- [ ] Auto-rebuild `.state/shows.json` when show.json files change. Options: git hook, fswatch, or just document "run build:index after edits".
- [ ] Consider whether `.state/shows.json` should be git-tracked or .gitignored (generated artifact vs portable state).

## Future Scripts

- [ ] `contract-status.sh` — Which shows have contract PDFs, which have contract-summary.md, which are approved.
- [ ] `calendar-view.sh` — Upcoming shows in a readable calendar format.
- [ ] `run-grouper.sh` — Identify natural run groupings from calendar gaps.
- [ ] `briefing-data.sh` — Gather all data needed for an AI-generated briefing.

## Claude Code Skills

- [ ] `/advance` — Orchestrate advancing workflow (uses advance-contacts.sh, adds AI for email composition).
- [ ] `/extract-contract` — Read a contract PDF, extract terms, create contract-summary.md.
- [ ] `/briefing` — Generate daily briefing from system state.
- [ ] `/audit` — Compare show.json vs contract-summary.md vs confirmed.md, flag mismatches.
