Scan the `intake/` directory and process every file found there.

## Processing rules

For each file in `intake/`:

### 1. Identify the file type

Read the file (PDFs, CSVs, text files) and classify it:

- **Contract PDF** — a deal memo or performance agreement for a specific show
- **Email thread PDF** — a printed email conversation (advancing, booking, production, merch, licensing, or general)
- **Routing CSV** — spreadsheet with show dates, venues, guarantees
- **Personnel CSV** — spreadsheet with crew, band, or contact info
- **Other** — flag for manual review

### 2. Process by type

#### Contract PDF
1. Match to an existing show by date/venue/city (search `org/.state/shows.json index`)
2. If no match found, ask the user which show this belongs to (or whether to create a new one)
3. Copy the PDF to `org/touring/shows/<show-id>/source/`
4. Extract key terms into `source/summary.md` with `status: pending-review`
5. Extract advancing contacts → add to `org/people.json` with `role: "advancing"` and `"Unconfirmed advancing contact."` in notes
6. **Write `_provenance`** on the show.json mapping the PDF to the fields extracted from it (see `ops/systems/provenance-plan.md` for the schema). The key is the relative path `source/FILENAME.pdf`, with `extracted` set to today's date and `fields` listing every show.json field substantiated by the contract.
7. Add a todo for human review of the contract summary
8. Report: what was extracted, confidence level, any ambiguities

#### Email thread PDF
1. Read the email and determine:
   - **Topic**: advancing, booking, production, merch, licensing, settlement, or general
   - **Related show**: match by venue/date/city if applicable
   - **Key people**: extract names, emails, roles mentioned
2. If it relates to a show:
   - Copy PDF to `source/` (primary source documents go here); derived summaries go in their workflow directories (`advancing/`, `settlement/`)
   - Update `advancing/thread.md` with a summary of the conversation
   - Extract any confirmed details into the relevant fields
   - Create or update todos for any action items
3. If it relates to a non-show topic (licensing, merch, releases, general band business):
   - Copy PDF to `org/comms/email/`
   - Create todos for any action items found in the thread
4. Add any new people mentioned to `org/people.json`
5. Report: what was found, what was updated, what needs follow-up

#### Routing CSV
1. Parse the spreadsheet and identify columns
2. Import shows, venues, and promoters following the patterns in `bandlab/ops/systems/conventions.md`
3. Report: what was created, what was updated, any conflicts

#### Personnel CSV
1. Parse the spreadsheet and identify columns
2. Import people into `org/people.json`
3. Report: what was created, what was updated

### 3. After processing each file

- Move the processed file to its permanent location (show directory, `org/comms/email/`, or `assets/`)
- If you can't determine where a file belongs, leave it in `intake/` and flag it in the report
- Rebuild the shows index: run `./bandlab-cli build-index`

### 4. Final report

After all files are processed, print a summary:
- Files processed and where they were routed
- New people/venues/shows created
- Todos created
- Anything left in `intake/` that needs manual attention
- Any contract summaries pending human review

## Important

- Always ask before creating a new show — the file might belong to an existing one
- Contract summaries are NEVER trusted until human-approved. Set `status: pending-review`
- When extracting contacts from contracts, mark them as unconfirmed
- Preserve original filenames when copying files to their destinations
- If `intake/` is empty, just say so
