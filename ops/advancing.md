# Advancing Workflow

## Overview

Advancing is the process of confirming show logistics with the venue before the date. It covers load-in times, soundcheck, hospitality, backline, parking, wifi, and anything else needed for a smooth show day.

## Contact Priority

Each venue has one or more potential advancing contacts in `people.json`, ranked by `advancing_priority`:

| Priority | Role | Rationale |
|---|---|---|
| 1 | Show Advance | Explicitly designated for advancing |
| 2 | Venue Contact | Knows the physical space and logistics |
| 3 | Production | Handles technical and staging logistics |
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
| `org` | Prefixed org reference: `"venue:venue-key"` or null for cross-venue contacts |
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

The touring party varies by geography and show type. Define your crew configurations in your private repo (e.g. `ops/crew-config.md`). This determines who to list in the advancing email.

## Querying

```bash
# Ranked contacts for a specific show
./tourlab advance:contacts s-2026-0315-denver

# Which shows still need advancing
./tourlab advance:status

# All advancing contacts, sorted by priority
jq -r '[to_entries[] | select(.value.role == "advancing")] | sort_by(.value.advancing_priority) | .[] | [.value.advancing_priority, .value.name, .value.org, .value.contact.email] | @tsv' org/.state/people.json
```
