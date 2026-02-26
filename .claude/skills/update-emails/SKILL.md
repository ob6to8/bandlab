Poll Gmail labels for new messages and update email thread summaries.

## Input

`$ARGUMENTS` accepts:
- `--dry-run` - scan and report only, no file changes
- A label name (e.g. `adv-spring-tour`) to scan a single label instead of all
- Both can be combined (e.g. `adv-spring-tour --dry-run`)

## Steps

### Phase 1 - Discover

1. Read `bandlab.config.json` and extract the `gmail.labels` config.
2. If `$ARGUMENTS` contains a specific label name, filter to that label only.
3. For each label, run `search_emails` with query `label:<label-name>` and `maxResults: 50`.
4. Collect all results. Build a map of `thread_id -> {subject, messages[], label, purpose, tour}`.
5. Deduplicate by `thread_id` - a thread appearing under multiple labels keeps the first label's metadata.

### Phase 2 - Match

1. Read all files matching `org/email/*.md`. For each file, parse YAML frontmatter and extract `thread_id`, `last` date, `status`, and filename.
2. Build a lookup: `thread_id -> {file, last, status}`.
3. Classify each discovered Gmail thread:
   - **STALE** - `thread_id` matches an existing summary AND the thread has messages dated after the summary's `last` date
   - **CURRENT** - `thread_id` matches AND no messages after `last` date
   - **NEW** - no `thread_id` match in any summary file

To check for new messages: compare the date of the most recent message in the Gmail search results against the `last` date in the summary frontmatter. If the Gmail message date is after `last`, the thread is STALE.

### Phase 3 - Report

Print a scan summary table:

```
## Email Scan Report

| Status  | Thread Subject                                      | File                          |
|---------|-----------------------------------------------------|-------------------------------|
| STALE   | ADVANCE: Dirtwire | Atlanta | Terminal West | Mar 5 | advance-atlanta-terminal-...   |
| CURRENT | Dirtwire | Charleston Pour House | ...             | advance-charleston-pour-...   |
| NEW     | ADVANCE: Dirtwire | Denver | Cervantes | Mar 15    | (will create)                 |

Summary: 2 stale, 5 current, 1 new
```

If `$ARGUMENTS` includes `--dry-run`, stop here. Print "Dry run complete - no changes made." and exit.

### Phase 4 - Process

Process STALE threads first, then NEW threads.

#### STALE threads

For each STALE thread:

1. **Read new messages.** `read_email` for each message ID that is newer than the summary's `last` date. Note the sender, date, and content of each.

2. **Register unknown participants.** For each message sender:
   - Check `org/people.json` by email address first, then by name
   - If not found, register them:
     - `role`: infer from context - `"advancing"` for venue advancing threads, `"promoter"` for promoter threads
     - `org`: `["venue:<venue-key>"]` for advancing threads (get venue key from the summary's associations)
     - `date_added`: today's date
     - `sources`: `["email:<thread subject>"]`
   - Present new registrations to the user for confirmation before writing

3. **Append Timeline entries.** For each new message, append a dated entry to the `## Timeline` section. Format: `- **YYYY-MM-DD** - [Sender name] [action summary with key details]`. NEVER edit or modify existing Timeline entries - append only.

4. **Update frontmatter:**
   - Set `last` to the date of the most recent new message
   - Add any new participant person-keys to `participants` (no duplicates)

5. **Update Open Items.** Review new messages against existing open items:
   - If a message resolves an open item, remove it from the list
   - If a message creates a new open item, add it
   - If a message partially addresses an item, update the description

6. **Update Summary.** Rewrite the `## Summary` section to reflect the current state of the thread, incorporating new information.

7. **Check for resolution.** If all open items are resolved and no further action is expected, set frontmatter `status` to `"resolved"`.

#### NEW threads

For each NEW thread:

1. **Read all messages.** `read_email` for every message in the thread. Note sender, date, content, and any attachments.

2. **Match to a show.** Parse the thread subject for venue name, city, and/or date. Cross-reference against day.json files in `org/touring/shows/`. If ambiguous, ask the user to confirm the match. If no match found, ask the user whether to create the summary without a show association.

3. **Register unknown participants.** Same process as STALE threads step 2.

4. **Determine filename.** Slugify the thread subject:
   - Strip prefixes: "ADVANCE:", "Re:", "Fwd:", "RE:", "FW:"
   - Strip "Dirtwire |" or "Dirtwire -" prefix if present
   - Lowercase, replace spaces with hyphens, strip special characters except hyphens
   - Example: "ADVANCE: Dirtwire | Atlanta | Terminal West | Mar 5" -> `advance-atlanta-terminal-west-mar-5`
   - If a file with that name already exists, ask the user

5. **Build associations.** From the matched show, pull:
   - `shows`: the show ID
   - `venues`: the venue key from day.json `venue.id`
   - `tours`: the tour key from day.json `day.tour`
   - For advancing threads (`purpose: "advancing"`), add `categories: ["advancing"]`

6. **Write the summary file** at `org/email/<slug>.md` with:
   - Full YAML frontmatter (thread, thread_id, status, first, last, participants, associations, categories, todos)
   - `## Summary` - concise description of the thread's purpose and current state
   - `## Open Items` - unresolved items
   - `## Timeline` - chronological message log

### Phase 5 - Finalize

1. Update `org/touring/.state/last-sync.json` - set `gmail` to the current ISO datetime.
2. Print a completion report:

```
## Update Complete

- Threads scanned: 15
- Updated (stale): 2
- Created (new): 1
- Already current: 12
- People registered: 1 (jane-doe)
```

## Important Rules

- **Timeline is immutable.** Never edit existing Timeline entries. Append only.
- **People first.** Register all unknown participants in `people.json` before writing or updating summary files. This ensures referential integrity.
- **Same-day dedup.** When checking if a message is "new", compare against the last Timeline entry for that date. If the sender and key content already appear, skip it.
- **No emdashes.** Use hyphens (-) in all output, never emdashes.
- **Frontmatter dates are ISO.** Always use YYYY-MM-DD format.
- **Associations must resolve.** Every person-key in `participants` must exist in `people.json`. Every show/venue/tour key must exist in its respective registry or directory.
- **Ask before writing people.json.** Present proposed new person registrations to the user for approval before modifying the registry.
