# bandlab

A file-based band management framework powered by AI agents. No database, no web app — just files, JSON, and shell scripts.

bandlab provides the schemas, scripts, workflows, and agent specification for managing a touring band's operations: shows, advancing, merch, releases, socials, licensing, and more.

## How it works

Your band's data lives in a private repo. bandlab is added as a git submodule, providing the framework — schemas, CLI tools, workflow docs, and the AI agent specification. You keep your shows, contacts, and finances private while benefiting from a shared, evolving toolset.

The directory tree is the data store. Every file is human-readable markdown or structured JSON. An AI agent (Claude Code or similar) maintains situational awareness and synthesizes knowledge into briefings, audits, and task tracking.

### What's in bandlab

- **`CLAUDE.md`** — Full system specification: schemas, directory structure, agent operations
- **`scripts/`** — Shell scripts (bash + jq) for querying and managing data
- **`ops/`** — Workflow documentation: advancing, conventions, architecture, glossary
- **`setup.sh`** — Scaffolds the `org/` directory tree for a new band
- **`band.example.json`** — Example config to copy into your private repo

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

This creates the full `org/` directory tree: calendar files for the current year, empty state JSON registries, an example show directory, and all domain directories.

### 4. Set up your CLI

Symlink bandlab's CLI into your repo root:

```bash
ln -s bandlab/bandlab my-band
```

Now you can run `./my-band show:list`, `./my-band audit:integrity`, etc.

### 5. Configure your band

Copy the example config into your repo:

```bash
cp bandlab/band.example.json band.json
```

Edit `band.json` with your band name, members, crew configurations, and hospitality preferences. This file is documentation for you and the agent — it's not consumed by scripts.

### 6. Set up your CLAUDE.md

Create a `CLAUDE.md` in your repo root that references bandlab's spec and adds your band-specific details:

```markdown
## Base Framework
See bandlab/CLAUDE.md for schemas, directory structure, and agent operations.

## Band-Specific Configuration
- Band name: My Band
- Members: Alice (advancing), Bob (settlement)
- Crew config: see ops/crew-config.md
- Contract format: see ops/contract-format.md
- Hospitality: [your preferences]
```

The `ops/` files referenced above live in your private repo, not in bandlab. They contain band-specific details like crew assignments by geography and your booking agent's contract format.

## Available commands

Run `./my-band` with no args for an interactive menu, or pass a command directly:

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
