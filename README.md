# bandlab

A file-based band management framework powered by AI agents. No database, no web app — just files, JSON, and shell scripts.

bandlab provides the schemas, scripts, workflows, and agent specification for managing a touring band's operations: shows, advancing, merch, releases, socials, licensing, and more.

## How it works

The directory tree is the data store. Every file is human-readable markdown or structured JSON. An AI agent (Claude Code or similar) maintains situational awareness and synthesizes knowledge into briefings, audits, and task tracking.

- **`CLAUDE.md`** — Full system specification: schemas, directory structure, agent operations
- **`scripts/`** — Shell scripts (bash + jq) for querying and managing data
- **`ops/`** — Workflow documentation: advancing, conventions, architecture, glossary

## Quickstart

### 1. Create your band repo

```bash
mkdir my-band && cd my-band
git init
```

### 2. Add bandlab as a submodule

```bash
git submodule add https://github.com/ob6to8/bandlab.git bandlab
```

### 3. Scaffold the org directory

```bash
bash bandlab/setup.sh
```

This creates the full `org/` directory tree: calendar files, empty state JSON, an example show, and all domain directories.

### 4. Set up your CLI entry point

Create a `my-band` script (or whatever you want to call it) in your repo root:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/bandlab/scripts"
# Delegate to bandlab's runner
exec bash "${REPO_ROOT}/bandlab/bandlab" "$@"
```

Or just symlink: `ln -s bandlab/bandlab my-band`

### 5. Configure your band

Copy and edit the example config:

```bash
cp bandlab/band.example.json band.json
```

Edit `band.json` with your band's name, members, crew config, and hospitality preferences.

### 6. Set up your CLAUDE.md

Create a `CLAUDE.md` in your repo root that references the bandlab spec:

```markdown
## Base Framework
See bandlab/CLAUDE.md for schemas, directory structure, and agent operations.

## Band-Specific Configuration
- Band name: My Band
- Members: ...
- Crew config: see ops/crew-config.md
- Contract format: see ops/contract-format.md
```

## Available commands

Run `./bandlab` with no args for an interactive menu, or pass a command directly:

| Command | Description |
|---|---|
| `show:list` | List all shows with date, venue, guarantee, and status |
| `show:info <id>` | Display details for a specific show |
| `build:index` | Rebuild .state/shows.json index from show.json files |
| `advance:contacts <id>` | Show ranked advancing contacts for a specific show |
| `advance:status` | Show advancing status across all shows |
| `audit:integrity` | Verify referential integrity across all state and data files |
| `export:dashboard` | Generate a static HTML dashboard from show/todo/venue data |

## Requirements

- bash
- [jq](https://jqlang.github.io/jq/)

## Design principles

- **Files over databases** — small org, portable data, git-diffable
- **Entities are files, the calendar is the schedule** — scheduling means linking
- **Master registries with key references** — one canonical source per entity
- **The todo owns the relationship** — one place to write, one place to query
- **Primary sources ground working data** — contracts and confirmations are truth; show.json is mutable

See `ops/architecture.md` for the full rationale.

## License

MIT
