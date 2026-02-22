Unified data browser and viewer. No query = list all, with query = show detail.

## Usage

`/list <entity> [query]`

## Supported entities

### shows
- `/list shows` — table of all shows (date, city, venue, status, guarantee)
- `/list shows atlanta` — detailed view of matching show(s) (all show.json fields formatted)

### tours
- `/list tours` — list tours with their runs and date ranges

### runs
- `/list runs` — list runs and one-offs with dates and show counts
- `/list runs east-coast-1` — detailed view of a specific run (all fields + show list)

### venues
- `/list venues` — list all venues (name, city, state, capacity)
- `/list venues terminal-west` — detailed view of a specific venue (all fields)

### people
- `/list people` — list all people (name, role, org)
- `/list people kyle-miller` — detailed view of a specific person (all fields)

### todos
- `/list todos` — list open todos grouped by domain (without history)
- `/list todos t005` — full detail on a specific todo including history

## Steps

1. Parse `$ARGUMENTS` to determine the entity type and optional query
2. If no arguments, show the list of supported subcommands above and exit
3. Read the relevant data file(s):
   - **shows**: read `org/touring/.state/shows.json`
   - **tours**: read `org/touring/tours/*/tour.json`
   - **runs**: read `org/touring/runs/*/run.json` and `org/touring/one-offs/*/one-off.json`
   - **venues**: read `org/touring/venues.json`
   - **people**: read `org/people.json`
   - **todos**: read `org/todos.json`
4. If a query is provided, filter/match by key, ID, or substring (case-insensitive)
5. Format output:
   - **List view**: markdown table with key columns
   - **Detail view**: all fields formatted as a readable block (not raw JSON)
6. Display the formatted output to the user

## Important

- For show detail, read the individual `show.json` from the show directory (not the index) to get the freshest data
- For todo list, always use `del(.history)` equivalent — only show history in detail view
- Match queries flexibly: `/list shows atlanta` should match `s-2026-0305-atlanta` by substring
- If no match found, say so clearly
