# Architecture

## Why This Exists

This is a file-based band management system. The directory tree is the data store. There is no database, no web app, no server. Every file is human-readable markdown or structured JSON. An AI agent enhances the system but does not gatekeep it.

## Tiered Knowledge System

A new agent context orients itself through progressive disclosure:

```
Level 0 — CLAUDE.md + MEMORY.md (auto-loaded every session)
│  Band-specific CLAUDE.md references bandlab/CLAUDE.md for base spec
│  Schema definitions, directory structure, current state, key patterns
│
Level 1 — ops/*.md (read the relevant doc for your task)
│  Two locations when used as a submodule:
│    bandlab/ops/  — generic workflows (advancing, conventions, architecture, glossary)
│    ops/          — band-specific (crew config, contract format, etc.)
│
Level 2 — Data files (read on demand)
   org/*.json registries, .state/ derived indexes, show.json files, calendar files, contracts
```

When consumed as a submodule, the private repo's CLAUDE.md provides band-specific context and references `bandlab/CLAUDE.md` for the base spec. The private repo's `ops/` supplements `bandlab/ops/` with band-specific details.

A new context's first reads: CLAUDE.md + MEMORY.md (automatic) → relevant ops/ doc. Total orientation cost: ~5K tokens.

## Why Shell Scripts

The CLI tools in `scripts/` are written in bash + jq. The reasons:

1. **Zero dependencies beyond jq.** No runtime to install, no virtualenv, no package manager. jq is the only external tool required and is widely available.
2. **Instant startup.** No VM boot time, no interpreter warmup.
3. **Composable.** Scripts read from stdin and write to stdout. They pipe into each other and into standard Unix tools.
4. **Transparent.** Anyone can read a 30-line bash script and understand exactly what it does.
5. **Matches the data model.** The state files are JSON. jq is the native query language for JSON. This is a natural fit.

### The Show Index

Show metadata lives in individual `show.json` files (one per show directory). Scripts can query any show directly with jq. For cross-show queries (e.g. "all shows with guarantee > 10000"), the index aggregates all show data into one file:

- `scripts/build-index.sh` merges all `show.json` files into `org/.state/shows.json`
- The merge is a trivial `jq` operation — no parsing, no transformation
- The index is regenerated when show data changes (run `./bandlab build-index`)
- Individual `show.json` files are the source of truth

Since both the source files and the index are JSON, there is no format translation and no drift risk. Scripts can read individual show files or the aggregate index depending on the use case.

## When to Move to Python

Move individual scripts to Python when:

- **Data joins become complex.** Correlating data across 3+ JSON files with conditional logic gets unwieldy in jq. Python makes this readable.
- **PDF reading is needed.** Contract extraction requires reading PDFs. This is an AI task today but could become a Python script with a PDF library.

The migration path: replace individual scripts one at a time. The entry point doesn't care whether a command is bash or Python — it just runs it.

## When to Move to Elixir

Move to Elixir when the system needs to be a **running service**, not just a CLI:

- **Slack bot.** Responding to advancing queries, posting briefings to channels.
- **Scheduled tasks.** Automated daily briefings, deadline reminders, sync operations.
- **Web dashboard.** Phoenix LiveView for tour status, calendar view, advancing tracker.
- **File watching.** Auto-rebuild indexes when files change, trigger workflows on new contracts.
- **Concurrent operations.** The BEAM VM excels at many lightweight processes doing I/O.

The file-based data model maps cleanly to Elixir's process model. Each show could be a GenServer. The JSON registries could be backed by ETS tables. The markdown files stay as-is.

This is a phase 2+ consideration. The shell foundation must work first.
