# Advancing Workflow

## Overview

Advancing is the process of confirming show logistics with the venue before the date. It populates the `advance` block in show.json — schedule, hospitality, backline, merch terms, parking, showers, loading, guest comps, wifi, labor, crew day, DOS contacts, hotels, settlement, and ticket count. See bandlab/CLAUDE.md for the full 18-field schema.

## Contact Priority

Each venue has one or more potential advancing contacts in `people.json`, ranked by `advancing_priority`:

| Priority | Role | Rationale |
|---|---|---|
| 1 | Show Advance | Explicitly designated for advancing |
| 2 | Production | Handles technical and staging logistics |
| 3 | Venue Contact | Knows the physical space and logistics |
| 4 | Promoter | Fallback when no dedicated production/venue contact exists |

Start outreach with priority 1 (if available), wait 2-3 days, then move to the next priority level if no response.

## Confirmation Lifecycle

Advancing contacts have `role: "advancing"` in `people.json`. Confirmation state is tracked in the `notes` field:

- **Unconfirmed**: `notes` includes "Unconfirmed advancing contact." — identified from contract, not yet confirmed.
- **Confirmed**: The "Unconfirmed" note is removed once the contact responds and is actively handling the advance.

## Fields Involved

### In people.json (per contact)

| Field | Purpose |
|---|---|
| `role` | `"advancing"` for all advancing contacts |
| `org` | Array of prefixed org references: `["venue:venue-key"]`, or null for non-venue people (band, crew, agents). Multi-venue contacts get multiple entries. |
| `advancing_priority` | 1-4 ranking (see table above) |
| `date_added` | When this contact was added to the registry |
| `notes` | Includes "Unconfirmed advancing contact." until confirmed; also contains contract title |

### In show directories (per show)

| Path | Purpose |
|---|---|
| `advancing/thread.md` | Running log of all outreach and responses |
| `advancing/confirmed.md` | Final confirmed details (structured frontmatter) |

### In show.json (status field)

Show status progresses: `confirmed` → `advanced` (once advancing is complete).

## Crew Assignments

The touring party varies by geography and show type. Define your crew configurations in your private repo (e.g. `ops/domain/crew.md`). This determines who to list in the advancing email.

## Querying

```bash
# Ranked contacts for a specific show
./bandlab-cli advance-contacts s-2026-0315-denver

# Which shows still need advancing
./bandlab-cli advance-status

# All advancing contacts, sorted by priority
jq -r '[to_entries[] | select(.value.role == "advancing")] | sort_by(.value.advancing_priority) | .[] | [.value.advancing_priority, .value.name, (.value.org // ["null"] | join(",")), .value.contact.email] | @tsv' org/people.json
```
