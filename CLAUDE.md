# Band Management Agent — System Specification

## Quick Start (for new agent contexts)

1. Read the relevant `ops/` doc for your task — `advancing.md`, `conventions.md`, `architecture.md`
2. CLI tools: run `./bandlab-cli` for an interactive menu, or `./bandlab-cli shows` directly
3. The `touring/.state/shows.json` index aggregates all show.json data — rebuild with `./bandlab-cli build-index`. Canonical registries (people, venues, vendors, todos) live in `org/`.

## What This Is

This is a file-based management system for a band organization. An AI agent (initially Claude Code operating interactively, eventually an autonomous agent) maintains situational awareness across all operational domains — touring, merch, socials, releases, licensing, distribution, and strategy — and synthesizes that knowledge into actionable briefings, audits, and task tracking.

There is no database. The directory tree IS the data store. Every file is human-readable markdown or structured JSON. The agent enhances this system — it does not gatekeep it. Anyone in the org should be able to open any file and understand what's going on without the agent running.

## Why It's Designed This Way

**Files over databases.** The system is designed for a small org (a band and its team), not enterprise scale. The data volume is small — hundreds of shows, not millions of rows. Files are portable, diffable with git, readable without tooling, and editable by humans or agents equally. A database may replace `touring/.state/` in the future when concurrent automated writes become a problem (Slack bot + cron + manual sessions writing simultaneously), but the markdown content files should remain as-is permanently.

**Entities are files, the calendar is the schedule, linking them is planning.** Shows, posts, and releases exist as standalone entities with their own metadata and content. They have no date until they're scheduled. Scheduling means linking the entity to a calendar date. This mirrors how bands actually work — you draft an announcement before you know when it's going out, you have a show offer before it's routed into a run.

**Master registries with key references, not duplicated data.** People, venues, and vendors each have a single canonical file. Everything else references them by key. This avoids drift — a venue's load-in instructions live in one place, not copied into every show file for that venue.

**The todo owns the relationship.** Todos reference their owners, not the other way around. One place to write, one place to query. Never two files that must be updated atomically.

**Primary sources ground the working data.** Show files contain the agent's working understanding. Contracts, advancing confirmations, and tech packs are the primary sources. The audit compares them and flags discrepancies. Contract summaries are agent-extracted but require human approval before they're trusted.

## Legible Architecture — Three-Tier Design

This framework uses a three-tier architecture where each tier declares its assumptions via config. The structure enforces comprehension — config files are contracts that declare "here's what I have and where it lives." When an agent runs a verification script, it can read `bandlab.config.json` to understand what's being checked without reading the script. The config becomes documentation.

| Tier | Location | What it knows |
|---|---|---|
| **General** | `~/.claude/skills/` | Session lifecycle. Reads `.claude/project.json` to discover CLI name and verification scripts. |
| **Framework** | `bandlab/` (submodule) | Generic engines. Reads `bandlab.config.json` for all paths, schemas, parameters. |
| **Client** | Repo root | Declares its data in `bandlab.config.json`. Contains `org/` data, `ops/` domain knowledge. |

Every framework script sources `scripts/lib/config.sh` and calls `load_config` to initialize paths from `bandlab.config.json`. No script hardcodes paths, registries, or domain vocabulary — everything is declared in the client's config file.

## Directory Structure

Generate the following directory tree. Create all files with the frontmatter and placeholder content described below. For the calendar, generate every day of your touring year (January through December).

```
org/
├── people.json                  # Canonical person registry
├── vendors.json                 # Canonical vendor registry
├── todos.json                   # Canonical task list
│
├── touring/
│   ├── shows/                   # One directory per show (s-YYYY-MMDD-city/)
│   ├── tours/                   # Top-level tour groupings
│   ├── runs/                    # Multi-show consecutive sequences (bounded by travel)
│   ├── one-offs/                # Single-show logistics blocks (bounded by travel)
│   ├── advancing/               # Band-level advancing resources
│   │   └── source/
│   │       └── riders/          # Club + festival rider files
│   ├── budgets/                 # Tour/run level budgets
│   ├── venues.json              # Canonical venue registry
│   ├── calendar/                # One markdown file per day, all year
│   │   ├── YYYY-01/
│   │   │   ├── 01.md ... 31.md
│   │   └── ... (through YYYY-12/)
│   ├── contacts.md              # Quick reference for touring contacts
│   └── .state/                  # Derived/generated state
│       ├── shows.json           # Generated index — run ./bandlab-cli build-index
│       └── last-sync.json
│
├── merch/
│   ├── inventory.md
│   ├── designs/
│   └── vendors.md
│
├── releases/
│   ├── catalog.md               # Back catalog reference
│   └── (individual release files: r-*.md)
│
├── socials/
│   ├── posts/                   # One file per post
│   ├── accounts.md              # Platforms, handles, access info
│   └── strategy.md
│
├── licensing/
│   ├── active/
│   ├── catalog.md
│   └── contacts.md
│
└── distro/
    ├── accounts.md
    ├── splits.md
    └── reporting.md
```

---

## Schema Definitions

### people.json

Path: `org/people.json`

The canonical registry of every person in the system. Band members, crew, managers, external contacts (promoters, talent buyers, vendor reps, label contacts, etc).

```json
{
  "person-key": {
    "name": "Full Name",
    "role": "their role relative to the band",
    "org": ["venue:venue-key"] or ["vendor:vendor-key"] or null,
    "contact": {
      "email": "",
      "phone": "",
      "slack": ""
    },
    "advancing_priority": null,
    "date_added": null,
    "sources": [],
    "notes": ""
  }
}
```

- `role`: This person's role relative to your band. Examples: `"advancing"` (advancing contact for a show), `"promoter"`, `"production"`, `"venue-contact"`, `"photographer"`, `"booking-agent"`, `"band"`, `"management"`, `"crew"`. For advancing contacts, unconfirmed status is noted in `notes` (e.g. "Unconfirmed advancing contact.").
- `org`: Array of prefixed keys linking to the organizations this person belongs to. `"venue:venue-key"` references `venues.json`, `"vendor:vendor-key"` references `vendors.json`. Null if the person isn't linked to a registered org (band, crew, agents). A person can belong to multiple orgs (e.g. a show advance who handles multiple venues gets `["venue:venue-a", "venue:venue-b"]`).
- `advancing_priority`: Integer 1-4 ranking for advancing outreach order. 1 = Show Advance, 2 = Venue Contact, 3 = Production, 4 = Promoter. Null for non-advancing contacts. See `ops/domain/advancing.md` for details.
- `date_added`: ISO date string (YYYY-MM-DD) when this person was added to the registry. Null for legacy entries.
- `sources`: Array of provenance references. Paths are relative to `org/` (e.g. `"touring/shows/s-2026-0304-charleston/source/DIRTWIRE_CharlestonPourHouse_DealMemo.pdf"`). Special values: `"manual"` (band/crew entered by hand), `"legacy"` (pre-provenance data), `"legacy:routing-csv"` (from routing spreadsheet import), `"legacy:contracts"` (from contract extraction, cross-venue).

Initialize with an empty object `{}`.

### venues.json

Path: `org/touring/venues.json`

Master list of venues. Accumulates institutional knowledge over time.

```json
{
  "venue-key": {
    "name": "Venue Name",
    "address": "Full street address",
    "city": "",
    "state": "",
    "capacity": null,
    "contacts": {},
    "sources": [],
    "notes": ""
  }
}
```

- `address`: Full street address of the venue (e.g. `"887 W Marietta St NW C, Atlanta, GA 30318"`). Empty string if unknown.
- `contacts`: Object mapping role to person key, e.g. `{"talent_buyer": "jane-doe", "production": "john-smith"}`.
- `sources`: Array of provenance references. Same format as people.json sources. Paths relative to `org/`.
- `notes`: Institutional knowledge — load-in details, green room info, quirks, history.

Initialize with an empty object `{}`.

### vendors.json

Path: `org/vendors.json`

Merch printers, distributors, PR firms, designers, etc.

```json
{
  "vendor-key": {
    "name": "Vendor Name",
    "type": "merch-printer|distributor|pr|design|...",
    "contact": "person-key",
    "notes": ""
  }
}
```

Initialize with an empty object `{}`.

### todos.json

Path: `org/todos.json`

Canonical task list. The agent reads and writes this. Syncs to external surfaces (spreadsheet, Slack) for human consumption.

```json
[
  {
    "id": "t001",
    "task": "Description of the task",
    "domain": "touring|merch|socials|releases|licensing|distro|strategy|general",
    "category": "freeform sub-classification or null",
    "show": "show-key or null",
    "owners": ["person-key"],
    "status": "open|in-progress|blocked|done",
    "due": "YYYY-MM-DD or null",
    "source": "Description of where this todo originated",
    "created": "YYYY-MM-DD",
    "updated": "YYYY-MM-DD",
    "blocked_by": ["todo-id"],
    "notes": "",
    "history": [
      {"date": "YYYY-MM-DD", "entry": "What happened"}
    ]
  }
]
```

- `category`: Freeform string for sub-classification within a domain (e.g. `"show-documentation"`, `"advancing"`, `"settlement"`). Null when not needed.
- `show`: Key into shows index when this todo relates to a specific show. Null otherwise.
- `owners`: Array of person keys (supports multiple owners).
- `blocked_by`: Array of todo IDs that must be completed before this todo can proceed. Null or omitted when not blocked. A todo with `blocked_by` entries where any referenced todo is not `"done"` is effectively blocked.
- `source`: Verbatim name of the originating thread/channel/context, prefixed by type. e.g. `"email:Festival Name // Topic"`, `"slack:2026-02-10"`, `"advancing:s-2026-0315-denver"`, `"manual"`.
- `updated`: ISO date, updated whenever any field on this todo changes.
- `notes`: Current-state summary. Overwritten as the situation evolves.
- `history`: Timestamped log of events. Append-only — entries are never edited or removed. Grows over the life of the todo. Default jq queries should use `del(.history)` to avoid pulling this into output unless specifically needed.

Initialize with an empty array `[]`.

### .state/last-sync.json

Path: `org/touring/.state/last-sync.json`

Timestamps for automated sync operations. Not relevant for the Claude Code prototype but the schema should exist.

```json
{
  "slack": null,
  "gmail": null,
  "spreadsheet": null
}
```

---

### Calendar Files

Path: `touring/calendar/YYYY-MM/DD.md`

Every day of the year gets a file. The frontmatter provides structured data for each domain. The body is freeform notes.

```markdown
---
date: YYYY-MM-DD
touring:
  type: null
schedule: []
releases: []
socials: []
---

## Notes
```

**Touring type values:** `show`, `travel`, `off`, `rehearsal`, `null` (no touring activity).

When a show is linked to this date:
```yaml
touring:
  type: show
  show: s-YYYY-MMDD-city
schedule:
  - time: "HH:MM"
    item: "Load-in"
    who: ["person-key"]
```

`who` is an array of person keys from `people.json` indicating who is involved in this schedule item (e.g. who is on a flight, who is performing).

When a travel day:
```yaml
touring:
  type: travel
  from: City
  to: City
  drive_hours: N
```

**releases** and **socials** are arrays of entity keys (e.g. `["r-single-spring-2026"]`, `["p-denver-announce"]`). Empty array when nothing is scheduled.

---

### Show Directory

Path: `touring/shows/s-YYYY-MMDD-city/`

Each show is a directory containing:

```
s-YYYY-MMDD-city/
├── show.json              # Working metadata — the agent's current understanding
├── tech-pack.md           # Stage plot, input list, backline requirements
├── source/                # Primary source documents (contracts, emails, etc.)
│   ├── *.pdf              # Original contract, email exports, etc.
│   └── summary.md         # Agent-extracted key terms (requires human approval)
├── advancing/             # Advancing workflow cycle
│   ├── thread.md          # Running log of advancing communications
│   └── confirmed.md       # Final confirmed details (structured frontmatter)
└── settlement/            # Post-show financials (empty until show happens)
    ├── settlement.md
    └── receipts/
```

**show.json:**

Three semantic namespaces — `deal` (contract terms), `venue` (advancing/venue capabilities), `band` (crew assignments) — plus top-level show identity and metadata.

```json
{
  "id": "s-YYYY-MMDD-city",
  "date": "YYYY-MM-DD",
  "status": "potential|offered|confirmed|advanced|settled|cancelled",
  "tour": "tour-key or null",
  "run": "run-key or null",
  "one_off": "one-off-key or null",
  "deal": {
    "guarantee": null,
    "canada_amount": "$CAD amount or null",
    "door_split": null,
    "promoter": "person-key",
    "ages": "all-ages|18+|21+",
    "ticket_link": "",
    "sell_cap": null,
    "ticket_scaling": null,
    "wp": null,
    "support": null,
    "sets": null
  },
  "venue": {
    "id": "venue-key",
    "hospitality": "",
    "video": "",
    "merch_cut": null,
    "merch_seller": "",
    "merch_tax_rate": "",
    "merch_notes": "",
    "parking": "",
    "showers": "",
    "load": "",
    "guest_comps": null,
    "wifi": {},
    "labor": "",
    "crew_day": "",
    "schedule": {
      "access": "",
      "load_in": "",
      "soundcheck": "",
      "support_check": "",
      "doors": "",
      "support_set": "",
      "headliner_set": "",
      "set_length": null,
      "curfew": "",
      "backstage_curfew": ""
    },
    "dos_contacts": {},
    "hotels": [],
    "settlement": "",
    "ticket_count": null
  },
  "band": {
    "band_member_1": "person-key or null",
    "band_member_2": "person-key or null",
    "foh": "person-key or null",
    "ld": "person-key or null",
    "vj": "person-key or null",
    "lasers": "person-key or null",
    "merch": "person-key or null",
    "driver": "person-key or null",
    "vehicle_type": "",
    "vehicle_length": "",
    "laminates": "",
    "backdrop": ""
  },
  "_provenance": {
    "source/FILENAME.pdf": {
      "extracted": "YYYY-MM-DD",
      "fields": ["deal.guarantee", "deal.door_split", "deal.ages", "..."]
    },
    "manual:person-key:YYYY-MM-DD": {
      "fields": ["venue.schedule", "venue.load"]
    },
    "user:person-key:YYYY-MM-DD": {
      "fields": ["band.foh", "band.driver"]
    }
  },
  "_verified": {
    "deal.guarantee": "YYYY-MM-DD",
    "venue.hospitality": "YYYY-MM-DD"
  }
}
```

- **deal fields:** Contract terms extracted from deal memos. Everything negotiated between artist and promoter/venue.
  - `guarantee`: USD guarantee amount (integer) or null for percentage deals.
  - `canada_amount`: CAD guarantee string for Canadian shows (e.g. `"$15,000.00"`). The `guarantee` field always stores USD. Null for non-Canadian shows.
  - `door_split`: Door/gross split terms as free text. Null if flat guarantee only.
  - `promoter`: Person-key of the promoter for this show.
  - `ages`: Age restriction (`"all-ages"`, `"18+"`, `"21+"`). Null if unknown.
  - `ticket_link`: URL to ticket sales page. Empty string if unknown.
  - `sell_cap`: Maximum ticket capacity (integer). Null if unknown.
  - `ticket_scaling`: Ticket price tiers (e.g. `"$25/$30"`). Null if unknown.
  - `wp`: Walkaway point — guaranteed revenue threshold (integer). Null if unknown.
  - `support`: Support act details (e.g. `"Buffalo Nichols, $500"`). Null if none.
  - `sets`: Array of set objects for multi-set festival appearances. Each entry has `date`, `time`, and `stage`. Null for standard single-set shows. Example: `[{"date": "2026-02-26", "time": "20:00-21:30", "stage": "Luna Stage"}]`.
- **venue fields:** Information gathered through advancing — what the venue provides, day-of-show logistics.
  - `id`: Venue key referencing `venues.json`.
  - `hospitality`: Catering/hospitality details (buyout amount, dressing room provisions).
  - `video`: Venue video capabilities (LED wall, projection, cat lines for VJ). Empty string if unknown.
  - `merch_cut`: Venue's percentage of merch sales (integer, e.g. `20`). Null if unknown.
  - `merch_seller`: Who sells merch — `"artist"`, `"venue"`, or details about local seller availability.
  - `merch_tax_rate`: Sales tax rate and who retains it (e.g. `"8.9% artist retains"`).
  - `merch_notes`: Freeform merch info (POS availability, special arrangements, etc.).
  - `parking`: Parking instructions for van/bus/trailer. Empty string if unknown.
  - `showers`: Shower availability. Empty string if unknown.
  - `load`: Loading notes (load-in/out help, dock info, elevator, stairs, etc.).
  - `guest_comps`: Number of complimentary guest list spots (integer). Null if unknown.
  - `wifi`: Object with network name/password pairs, keyed by area (e.g. `{"backstage": "Net / pass123"}`). Empty object if unknown.
  - `labor`: House tech/labor details (e.g. `"3 house techs: FOH, MON, LD"`).
  - `crew_day`: Crew day length and overage terms.
  - `schedule`: Object with day-of-show timing. All time fields are strings (e.g. `"3:30 PM"`). `set_length` is integer minutes or null. `backstage_curfew` is freeform (e.g. `"90 min after show ends"`).
  - `dos_contacts`: Object mapping person-key to phone number for day-of-show contacts.
  - `hotels`: Array of hotel name strings with discount codes (e.g. `["Wiley Hotel (code: ZEROMI)"]`).
  - `settlement`: Settlement method (e.g. `"check or wire"`).
  - `ticket_count`: Current ticket count at time of advancing (integer). Null if unknown.
- **band fields:** Structured block mapping roles to person-keys. Role fields are `"person-key"` or `null` (unfilled/not traveling).
  - `band_member_1`, `band_member_2`: Band members traveling to this show.
  - `foh`: Front of house engineer.
  - `ld`: Lighting director.
  - `vj`: Visual artist (Touch Designer/Resolume).
  - `lasers`: Laser and floor lighting operator.
  - `merch`: DOS merch coordinator.
  - `driver`: Tour vehicle driver.
  - `vehicle_type`: String (e.g. `"Sprinter"`, `"SUV"`, `""`). Empty string if unknown.
  - `vehicle_length`: String (e.g. `"25ft"`, `""`). Empty string if unknown.
  - `laminates`: Whether the band is carrying laminates for this show (e.g. `"yes"`, `"no"`, `""`). Empty string if unknown.
  - `backdrop`: Whether the band is carrying a backdrop and what size (e.g. `"yes, 10x20"`, `"no"`, `""`). Empty string if unknown.
- `_verified`: Flat object mapping field names to ISO dates (YYYY-MM-DD) indicating when a human confirmed the field value is correct. Uses dot-notation matching `_provenance` field names (e.g. `"venue.hospitality"`, `"deal.guarantee"`). Empty object `{}` by default. Underscore-prefixed so jq queries ignore it.
- `_provenance`: Maps source documents to the fields they substantiate. Underscore-prefixed so jq queries and existing scripts ignore it. Keys are paths relative to the show directory, or special values: `"manual:<person>:<date>"` (agent entered data a person provided verbally/in-session), `"user:<person>:<date>"` (user directly provided the data), `"legacy"`, `"legacy:routing-csv"`. Each entry has `extracted` (ISO date) and `fields` (array of dot-notation field names, e.g. `"deal.guarantee"`, `"venue.parking"`, `"band.foh"`). Non-file key prefixes (`manual:`, `user:`, `legacy:`) must be registered in `bandlab.config.json` under `provenance.special_source_prefixes` so verification scripts skip file-existence checks. See `ops/provenance-plan.md` for the full design.

**source/summary.md frontmatter:**
```yaml
---
source: contract
extracted_date: YYYY-MM-DD
status: pending-review|approved
approved_by: null
approved_date: null
guarantee: null
door_split: null
merch_cut: null
ages: null
radius_clause: ""
cancellation: ""
---

## Agent Notes
[Agent documents extraction confidence and flags ambiguities here]
```

**advancing/confirmed.md frontmatter:**
```yaml
---
source: advancing
confirmed_date: YYYY-MM-DD
load_in: ""
soundcheck: ""
doors: ""
set_time: ""
guarantee: null
hospitality: ""
backline: ""
merch_cut: null
ages: null
parking: ""
wifi: ""
---

## Advancing Thread Summary
[Chronological log of what was discussed and confirmed]
```

**The audit trust hierarchy:**
1. `source/summary.md` (approved) — highest trust, human-verified legal terms
2. `confirmed.md` — high trust, reflects advancing agreements
3. `show.json` — working copy, agent-maintained, mutable

The audit compares all three and flags mismatches and missing approvals.

When generating show directories for the initial scaffold, create one example show directory with all files populated with placeholder content to demonstrate the structure.

---

### Run Directories

Path: `touring/runs/run-key/run.json`

Runs are multi-show consecutive sequences bounded by travel. Each directory holds `run.json` plus scoped todos (e.g. vehicle rental, lodging block).

```json
{
  "id": "run-key",
  "tour": "tour-key",
  "dates": ["YYYY-MM-DD", "YYYY-MM-DD"],
  "shows": ["show-key", "..."],
  "status": "routing|confirmed|in-progress|complete",
  "notes": ""
}
```

### One-off Directories

Path: `touring/one-offs/one-off-key/one-off.json`

One-offs are single-show (or multi-set festival) logistics blocks bounded by travel. The date range spans from first arrival to last departure. Schema is identical to run.json.

```json
{
  "id": "one-off-key",
  "tour": "tour-key or null",
  "dates": ["YYYY-MM-DD", "YYYY-MM-DD"],
  "shows": ["show-key"],
  "status": "routing|confirmed|in-progress|complete",
  "notes": ""
}
```

Every show has exactly one non-null logistics block reference: either `run` (multi-show) or `one_off` (single-show). Query both to find all logistics blocks.

### Tour Directories

Path: `touring/tours/tour-key/tour.json`

Tours are directories that hold `tour.json` plus tour-scoped todos (e.g. crew travel, budgeting).

```json
{
  "id": "tour-key",
  "status": "planning|routing|confirmed|in-progress|complete",
  "dates": ["YYYY-MM-DD", "YYYY-MM-DD"],
  "runs": ["run-key", "..."],
  "one_offs": ["one-off-key", "..."],
  "shows": ["show-key", "..."],
  "notes": ""
}
```

---

### Social Posts

Path: `socials/posts/p-slug.md`

```yaml
---
id: p-slug
status: draft|scheduled|posted
date: YYYY-MM-DD or null
platform: [instagram, twitter, tiktok, facebook, ...]
linked_to: entity-key or null
assets: []
---

[Post content body — ready to copy/paste or push through API]
```

- `linked_to`: Optional reference to the entity this post is about (e.g. `s-2026-0315-denver`, `r-single-spring-2026`).
- `date` is null until scheduled. When scheduled, the corresponding calendar file should reference this post key in its `socials` array.

---

### Release Files

Path: `releases/r-slug.md`

```yaml
---
id: r-slug
title: ""
type: single|ep|album
status: planning|in-progress|delivered|released
street_date: YYYY-MM-DD or null
distributor: vendor-key or null
deliverables:
  mastering_due: null
  artwork_due: null
  distributor_delivery: null
  metadata_due: null
---

## Overview

## Assets

## Promo Plan
```

When deliverable dates are set, the corresponding calendar dates should reference this release key in their `releases` array.

---

## Agent Operations

### Audit

The audit scans all show directories and compares structured data across:
- `show.json` (working data)
- `source/summary.md` (legal terms, if approved)
- `confirmed.md` (advancing confirmations)
- Calendar file for that date

Flags: field mismatches, unapproved contract summaries, missing files (show confirmed but no contract on file), schedule inconsistencies.

### Contract Extraction

When a contract PDF is added to a show directory:
1. Agent reads the PDF and extracts key terms into `source/summary.md`
2. Sets `status: pending-review`
3. Documents confidence and ambiguities in the Agent Notes section
4. Adds a todo for human review
5. The summary is NOT treated as trusted data until a human sets `status: approved`

### Task Management

Querying todos from the terminal (note: `del(.history)` strips the history array from output to keep queries lightweight):
```bash
# All open todos (without history)
jq '[.[] | select(.status == "open") | del(.history)]' org/todos.json

# A specific person's open todos
jq '[.[] | select((.owners | index("alice")) and .status == "open") | del(.history)]' org/todos.json

# Touring domain
jq '[.[] | select(.domain == "touring" and .status != "done") | del(.history)]' org/todos.json

# Full history for a specific todo
jq '.[] | select(.id == "t001") | .history' org/todos.json

# All todos for a specific show
jq '[.[] | select(.show == "s-2026-0315-denver") | del(.history)]' org/todos.json
```
