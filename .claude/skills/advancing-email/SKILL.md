Compose or reply to an advancing email for a show.

## Steps

1. Read `ops/systems/advancing-email-guide.md` for composition rules and formatting
2. Identify the show from `$ARGUMENTS` (show ID or partial match)
3. Load data sources:
   - `show.json` for the target show
   - `tour.json` for the show's tour
   - `advancing-email-questions-club.json` for question text
   - `advancing-email-template-club.json` for email structure and touring party
   - Find current rider PDF in `org/touring/assets/`
4. Determine email type:
   - **Reply**: If the venue has already sent an advance, cross-reference their info against the questions file. Answer their questions, confirm what they provided, ask only unanswered questions.
   - **Initial outreach**: If we're initiating, use the full template structure.
5. Compose the email following the guide's formatting rules (ALL CAPS headings, numbered touring party, DRY — refer to rider for hospo/backline/tech)
6. Write draft to `org/touring/shows/<show-id>/advancing/reply-draft.txt` (plain text, no markdown)
7. Present the draft to the user for review
8. After user approval, attach rider PDF and finalize. User will copy-paste into Gmail.
