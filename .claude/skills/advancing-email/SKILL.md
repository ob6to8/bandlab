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

3. **Find the Gmail thread** for this show. Search by the `email_thread_1` field in show.json, or by the subject passed in `$ARGUMENTS`. Read all messages in the thread to understand what the venue asked and what info they provided. Note the `threadId` and latest message ID for `inReplyTo`.

4. **Load data sources:**
   - `show.json` for the target show
   - `tour.json` for the show's tour
   - `advancing-email-questions-club.json` for question text
   - `advancing-email-template-club.json` for email structure and touring party
   - Find current rider PDF in `org/touring/assets/`

5. **Determine email type:**
   - **Reply**: If the venue has already sent an advance, cross-reference their info against the questions file. Answer their questions, confirm what they provided, ask only unanswered questions.
   - **Initial outreach**: If we're initiating, use the full template structure.

6. **Compose the email** following the guide's formatting rules (ALL CAPS headings, numbered touring party, plain text, DRY — refer to rider for hospo/backline/tech)

7. **Write draft** to `org/touring/shows/<show-id>/advancing/reply-draft.txt` (plain text, no markdown) as a backup for copy-paste.

8. **Present the draft** to the user for review before creating the Gmail draft.

9. **After user approval**, create the Gmail draft via `draft_email`:
   - Set `threadId` and `inReplyTo` from step 3
   - Set `to` from the venue contact's email (from the thread)
   - Attach the rider PDF via `attachments`
   - Note: API-created drafts may not appear inline in the Gmail thread view. The user can find the draft in their Drafts folder, or use the `.txt` backup to copy-paste into a manually composed reply.
