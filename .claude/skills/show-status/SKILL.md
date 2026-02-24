Show advancing status and outstanding info for a single show.

## Input

`$ARGUMENTS` is a city name or show ID (e.g. `atlanta`, `s-2026-0305-atlanta`).

## Steps

1. **Resolve the show** from `$ARGUMENTS`. Match against show IDs (partial match on city name).

2. **Read the thread log** at `org/touring/shows/<show-id>/advancing/thread.md` (or `thread-status.md` if renamed). If no thread file exists, report "No advancing thread started."

3. **Read show.json** for the show.

4. **Read advancing questions** from `advancing-email-questions-club.json` (path from `bandlab.config.json`).

5. **Check each advancing question for completeness:**
   - For questions with `fields`: check if the corresponding show.json fields are populated (non-empty string, non-null, non-empty object/array).
   - For questions with empty `fields` (ethernet_hdmi, food_deals, foh_contact, tech_pack): check the thread log for evidence the question was asked AND answered. If uncertain, mark as outstanding.

6. **Check for source documents** in `org/touring/shows/<show-id>/source/` — tech pack, deal memo, etc.

7. **Output a summary:**

   ```
   ADVANCING STATUS: <show-id>
   <venue-name> — <city>, <state> — <date>

   THREAD
   <thread log contents, or "No thread started">

   ANSWERED (X/15)
   ✓ schedule — 3:00 PM access, 3:30 load, 5:00 SC, 9:30 set
   ✓ parking — Entrance 2, King Plow Arts Center
   ...

   OUTSTANDING (X/15)
   ✗ video — asked 2/23, awaiting reply
   ✗ foh_contact — asked 2/23, awaiting reply
   ...

   SOURCE DOCUMENTS
   ✓ deal memo
   ✓ tech pack
   ✗ signed rider
   ```

8. **Summarize next actions** — what needs to happen to complete advancing for this show.
