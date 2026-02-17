# Conventions

Patterns established across the codebase. Follow these when adding new data.

## Key Naming

**Show IDs:** `s-YYYY-MMDD-city` — lowercase, hyphenated city name.
- `s-2026-0304-charleston`, `s-2026-0614-morrison`
- Two shows in the same city get different dates, so no suffix needed.
- Two shows at the same venue on different dates (e.g., a venue hosts multiple festivals) are distinguished by date.

**Venue keys:** Lowercase hyphenated venue name.
- `belly-up-aspen`, `red-rocks`, `10-mile-music-hall`

**Person keys:** `first-last`, with venue suffix if name collision.
- `chris-brown-visulite` (disambiguated from other Chris Browns)
- `justin-brown-orh` (disambiguated by venue abbreviation)

## File Organization

**The filesystem is for content. JSON is for status.**

A todo that accumulates artifacts (emails, documents, confirmations) becomes a file or directory. A todo that's just a task to track stays in `todos.json`.

**Directories are workflow cycles, not file-type buckets.** Don't group by type (all contracts in one folder, all tech packs in another). Group by the work being done — the show directory contains everything about that show, organized by workflow.

Within a show directory:
- **Single-asset items** are files: `tech-pack.md`, `show.json`
- **Multi-asset workflows** are directories: `source/` (primary source documents — contracts, email exports, etc. + summary), `advancing/` (thread log + confirmed details), `settlement/` (settlement sheet + receipts)

**Scoped todos live in their scope's directory:**
- **Show-level**: `touring/shows/s-YYYY-MMDD-city/` — show-specific workflows and assets
- **Run-level**: `touring/runs/run-key/` — todos spanning a week of consecutive shows (e.g. vehicle rental, lodging block)
- **Tour-level**: `touring/tours/tour-key/` — todos spanning the full tour (e.g. crew travel arrangements, tour budgeting)
- **Domain-level**: the relevant domain directory (`merch/`, `socials/`, `releases/`, etc.)

If it's just status tracking with no accumulated content, it stays in `todos.json`. If it starts accumulating files (email chains, quotes, docs), it becomes a file or directory at the appropriate scope.

**Tours, runs, and one-offs:**
- A **tour** is the top-level grouping. It references all its shows — both run shows and one-offs.
- A **run** is a consecutive sequence of shows within a tour (typically a weekly leg).
- A **one-off** is a show that belongs to a tour but not to any run (e.g. a standalone festival). One-offs don't need their own directory type — they're just shows with `run: null` in show.json. The tour references them alongside the runs.
- Show directories hold all show content regardless of whether the show is in a run or a one-off.

**Rule of thumb:** if you'd attach files to it, it's a directory. If you'd just check a box, it's a JSON entry.

## show.json Fields

**guarantee:** Dollar amount as integer, or `null` for pure percentage deals.
- `3500` not `3500.00`

**door_split:** Concise string describing the percentage deal, or `null` for flat guarantees.
- `"vs 85% of gross after expenses and taxes"` — guarantee vs percentage, whichever is greater
- `"plus 80% of gross after expenses and taxes"` — guarantee plus percentage overage
- `"65% of gross from dollar one, less taxes and support"` — pure percentage, no guarantee
- `null` — flat guarantee with no percentage component

**merch_cut:** The venue's percentage cut on soft goods (integer), or `null`.
- `0` — artist keeps 100%
- `15` — venue takes 15% on soft goods
- `null` — merch not sold at event, or terms unknown
- When soft and hard goods have different rates, this reflects the soft goods rate (the more financially significant number).

**ages:** One of `all-ages`, `18+`, `21+`.

**status:** One of `potential`, `offered`, `confirmed`, `advanced`, `settled`, `cancelled`.

**promoter:** Person key of the primary promoter/purchaser contact, or `null` if not in the registry.

## Source Provenance

Every data record tracks where it came from via a `sources` array.

**Where source files live:** Each show directory has a `source/` subdirectory holding primary source documents — contract PDFs, email exports, and any other original artifacts. Derived files (thread summaries, confirmed details) stay in their workflow directories (`advancing/`, `settlement/`).

**The `sources` field** on `people.json` and `venues.json` entries is an array of provenance references:

- **File paths** (relative to `org/`): `"touring/shows/s-2026-0304-charleston/source/DIRTWIRE_CharlestonPourHouse_DealMemo.pdf"`
- **Special values**: `"manual"` (entered by hand), `"legacy"` (pre-provenance data), `"legacy:routing-csv"` (from routing spreadsheet import), `"legacy:contracts"` (from contract extraction, cross-venue)

File-path sources must resolve to actual files on disk. The audit checks this.

Shows implicitly reference their own `source/` directory — no `sources` field needed on `show.json`.

## Contract Sources

Document your contract format in `ops/contract-format.md` in your private repo. Key sections typically include compensation, ages, merchandise terms, venue/production contacts, and special provisions.
