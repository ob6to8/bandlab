Unified data browser and viewer. No query = list all, with query = show detail.

## Usage

`/list <entity> [query]`

## Config discovery

Read `bandlab.config.json` to discover entity paths and registries. Key references:
- Shows index: `.entities.shows.index_path`
- Shows directory: `.entities.shows.dir`
- Tours: `.entities.tours.dir`
- Runs: `.entities.runs.dir`
- One-offs: `.entities.one_offs.dir`
- Venues: `.registries.venues.path`
- People: `.registries.people.path`
- Todos: `.registries.todos.path`

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
3. Read `bandlab.config.json` and resolve the path for the requested entity type:
   - **shows**: read the shows index at `entities.shows.index_path`
   - **tours**: read `entities.tours.dir/*/tour.json`
   - **runs**: read `entities.runs.dir/*/run.json` and `entities.one_offs.dir/*/one-off.json`
   - **venues**: read `registries.venues.path`
   - **people**: read `registries.people.path`
   - **todos**: read `registries.todos.path`
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
