# Architecture

## Why This Exists

This is a file-based band management system. The directory tree is the data store. There is no database, no web app, no server. Every file is human-readable markdown or structured JSON. An AI agent enhances the system but does not gatekeep it.

## Ops Directory Structure

`ops/` is organized into three subdirectories in both the framework repo and the private band repo:

```
ops/
├── systems/         # How things work — architecture, conventions, protocols
│   └── index.md     # Lists all system docs
├── domain/          # Subject matter knowledge — modular files per topic
│   └── index.md     # Lists all domain files with trigger keywords
└── plans/           # Future work, setup docs, proposals
```

### Why This Structure

A flat `ops/` directory works at small scale but breaks down as files accumulate. Three problems emerge:

1. **Category confusion.** System docs (how the rider system works), domain knowledge (what a drive line is), and plans (mobile app architecture) serve different purposes but look identical in a flat listing. An agent doesn't know which files are relevant without reading them all.

2. **Progressive disclosure breaks.** The tiered knowledge system (below) requires agents to load only what's relevant. A flat directory forces a linear scan. Subdirectories with index files let agents read a ~200 token index, match against their current task, and load only the matching files.

3. **Two-repo coherence.** Both the framework (`bandlab/ops/`) and the private repo (`ops/`) use the same structure. A new agent immediately knows where to look: `systems/` for how things work, `domain/` for what they need to know, `plans/` for future work.

### Category Definitions

**`systems/`** — Documents that describe how a system in this codebase works. Architecture decisions, data conventions, protocol definitions. An agent reads these when it needs to understand or extend a system. Examples: the rider block system, the provenance model, key naming conventions.

**`domain/`** — Subject matter knowledge that an agent needs to do its job. Each file covers one topic and has `triggers` in its frontmatter — keywords that indicate when to load it. An agent doing merch work loads `domain/merch.md`; an agent doing advancing loads `domain/advancing.md`. Examples: how FOH signal flow works, what a deal memo contains, how monitoring rigs are configured.

**`plans/`** — Documents about work not yet done, setup instructions, and proposals. These are referenced when needed but not part of routine agent orientation. Examples: mobile app plan, Gmail MCP setup.

### Framework vs Private Repo

**Framework (`bandlab/ops/`)** contains generic music management knowledge and system architecture — concepts that apply to any band using bandlab. This is opinionated: bandlab defines the conventions, and band data repos conform to them.

**Private repo (`ops/`)** contains band-specific knowledge that conforms to the framework's conventions. The domain files here cover the specific band's setup (their signal chain, their crew, their hospitality preferences), not generic industry knowledge.

## Tiered Knowledge System

A new agent context orients itself through progressive disclosure:

```
Level 0 — CLAUDE.md + MEMORY.md (auto-loaded every session)
│  Band-specific CLAUDE.md references bandlab/CLAUDE.md for base spec
│  Schema definitions, directory structure, current state, key patterns
│
Level 1 — ops/ index files (cheap reads to determine what's relevant)
│  ops/systems/index.md — list of system docs
│  ops/domain/index.md  — list of domain knowledge files with triggers
│  Two locations when used as a submodule:
│    bandlab/ops/  — generic (production, advancing, contracts, merch, touring)
│    ops/          — band-specific (live setup, crew, hospitality, personnel)
│
Level 2 — Specific ops/ files (read only what's relevant to your task)
│  Each domain file has frontmatter with trigger keywords
│  Match your current task against triggers, load matching files
│
Level 3 — Data files (read on demand)
   org/*.json registries, .state/ derived indexes, show.json files, calendar files, contracts
```

### Progressive Disclosure Protocol

1. **CLAUDE.md loads automatically** — provides the full schema spec and directory structure (~5K tokens)
2. **Read the relevant index** — `ops/domain/index.md` lists all domain files with "Read when working on..." descriptions (~200 tokens)
3. **Load only matching domain files** — each file has `triggers` in its frontmatter. Match your task keywords against triggers. Only load files that match.
4. **Load system docs as needed** — if the task involves a specific system (rider blocks, provenance), read the relevant `ops/systems/` doc.

Total orientation cost for a focused task: CLAUDE.md (~5K) + index (~200) + 1-2 domain files (~1-2K each) = ~7-8K tokens. An agent doing merch work never loads the production doc.

## Rider System

Riders are maintained as modular blocks tagged with conditions (venue type, FOH configuration, VJ presence). Assembled per scenario to prevent drift across multiple rider documents. See `ops/systems/rider-system.md` in the private repo for the full protocol.

### Rider Artifacts

Final assembled riders for email attachment live in `org/touring/assets/`. Convention:
- **Directory name** describes the rider variant: `Dirtwire Rider - Spring 2026 (Club - No LD)`
- **File inside** is named generically for attachment: `Dirtwire Rider - Spring 2026.pdf`

The directory name provides context for the sender; the file name reads cleanly in the recipient's inbox.

### Internal vs External

Production details (what the band carries, signal flow, gear inventory) live in tour-level production docs at `org/touring/tours/<tour-key>/production.md`. The rider only contains what the venue needs to know. These documents intentionally overlap on some facts — the rider must be standalone.

## Tour-Level Production Docs

Each tour with significant production decisions has a `production.md` in its tour directory. This captures carried gear inventory, signal flow, monitoring setup, and internal routing decisions. Provenance links back to the source document (email thread, meeting notes) where decisions were made.

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
- The index is regenerated when show data changes (run `./bandlab-cli build-index`)
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
