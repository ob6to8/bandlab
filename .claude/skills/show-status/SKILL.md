Show advancing status and outstanding info for a single show.

## Input

`$ARGUMENTS` is a city name or show ID (e.g. `atlanta`, `s-2026-0305-atlanta`).

## Steps

1. **Resolve the show** from `$ARGUMENTS`. Match against show IDs (partial match on city name).

2. **Read day.json** for the show.

3. **Read advancing questions** from `advancing-email-questions-club.json` (path from `bandlab.config.json`).

4. **Check advancing status using the advance object** (preferred) or legacy field checks (fallback):

   **If day.json has an `advance` key** (state machine):
   - Read each question's `status` and `notes` from `day.json.advance.<question_id>`
   - Group questions by status: `confirmed`, `asked`, `needs_response`, `need_to_ask`, absent
   - For each question, show status + last note date + summary text

   **If no `advance` key** (legacy fallback):
   - For questions with `fields`: check if the corresponding day.json fields are populated (non-empty string, non-null, non-empty object/array).
   - For questions with empty `fields`: check the thread log at `advancing/thread.md` for evidence. If uncertain, mark as outstanding.

5. **Check for source documents** in `org/touring/sources/<date-id>/` (date-id uses `MM-DD-YY-suffix` format, e.g. `03-05-26-atlanta`) - tech pack, deal memo, etc.

6. **Output a summary:**

   ```
   ADVANCING STATUS: <show-id>
   <venue-name> - <city>, <state> - <date>

   CONFIRMED (X/17)
   + schedule         confirmed  2026-02-24  Cate confirmed schedule is perfect
   + parking          confirmed  2026-02-24  Cate confirmed can park early
   ...

   AWAITING RESPONSE (X/17)
   ~ video            asked          2026-02-23  Asked about LED wall or projection
   ~ ethernet_hdmi    needs_response 2026-02-26  Venue said 'sometimes'
   ...

   NOT YET ASKED (X/17)
   - backdrop         need_to_ask    2026-02-24  Not included in initial advance
   ...

   SOURCE DOCUMENTS
   + deal memo
   + tech pack
   - signed rider
   ```

7. **Summarize next actions** - what needs to happen to complete advancing for this show. Prioritize:
   - `needs_response` items (venue replied but inconclusive)
   - `need_to_ask` items (gaps in the advance email)
   - `asked` items awaiting reply (may need follow-up if stale)
