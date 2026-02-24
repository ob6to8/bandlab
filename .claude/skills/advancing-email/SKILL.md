Compose or reply to an advancing email for a show.

## Input

`$ARGUMENTS` accepts either:
- A **show ID** or partial match (e.g. `atlanta`, `s-2026-0305-atlanta`)
- An **email thread subject** in quotes (e.g. `"ADVANCE: Dirtwire | Atlanta | Terminal West | Mar 5"`)

## Steps

1. Read `ops/systems/advancing-email-guide.md` for composition rules and formatting

2. **Resolve the show:**
   - If `$ARGUMENTS` is a quoted email subject: search Gmail for the thread, extract the city/venue from the subject line, match to a show ID.
   - Otherwise: match `$ARGUMENTS` as a show ID or partial.

3. **Find the Gmail thread** for this show. Search by the `email_thread_1` field in show.json, or by the subject passed in `$ARGUMENTS`.

4. **Verify a draft exists in Gmail.** Search `in:draft` for the thread subject.
   - If NO draft is found: **STOP.** Ask the user to create a draft in Gmail first (Reply All on the thread), then re-run the skill. Do NOT create a draft via API.
   - If a draft is found: continue.

5. **Read the thread.** Read all messages in the thread to understand what the venue asked and what info they provided.

6. **Load data sources:**
   - `show.json` for the target show
   - `tour.json` for the show's tour
   - `advancing-email-questions-club.json` for question text
   - `advancing-email-template-club.json` for email structure and touring party
   - Find current rider PDF in `org/touring/assets/`

7. **Determine email type:**
   - **Reply**: If the venue has already sent an advance, cross-reference their info against the questions file. Answer their questions, confirm what they provided, ask only unanswered questions.
   - **Initial outreach**: If we're initiating, use the full template structure.

8. **Compose the email** following the guide's formatting rules (ALL CAPS headings, numbered touring party, plain text, DRY — refer to rider for hospo/backline/tech)

9. **Write draft** to `org/touring/shows/<show-id>/advancing/reply-draft.txt` (plain text, no markdown)

10. **Present the draft** to the user for review. Remind them to attach the rider PDF when sending.
