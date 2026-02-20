# Advancing Initial Outreach

Template for the first advancing email sent to a venue contact.
The agent populates `{{placeholders}}` from the data store.

## Data sources

| Placeholder | Source |
|---|---|
| `{{band_name}}` | Band name from your config |
| `{{venue_name}}` | `venues.json[show.venue].name` |
| `{{venue_city}}` | `venues.json[show.venue].city` |
| `{{venue_state}}` | `venues.json[show.venue].state` |
| `{{show_date}}` | `show.json.date` — format as `M.DD.YYYY` |
| `{{touring_party}}` | `people.json` filtered by role (band, foh, vj, etc.) — numbered list of who's traveling |
| `{{foh_name}}` | `people.json` entry with role `foh` — full name |
| `{{foh_phone}}` | `people.json` entry with role `foh` — phone |
| `{{vj_name}}` | `people.json` entry with role `vj` — full name (conditional on video capability) |
| `{{merch_manager_name}}` | person handling merch management — name |
| `{{merch_manager_email}}` | person handling merch management — email |
| `{{merch_manager_phone}}` | person handling merch management — phone |
| `{{merch_dos_name}}` | DOS merch coordinator — name |
| `{{merch_dos_phone}}` | DOS merch coordinator — phone |
| `{{set_length}}` | from show.json or default `90min` |
| `{{settling_member}}` | band member designated for settlement — full name |
| `{{sender_name}}` | person sending the email (management or DOS contact) |

## Conditional sections

- **VJ line in touring party**: include only if venue has video capabilities or unknown (ask)
- **Video section**: always include — determines whether VJ travels

---

## Template

This is to advance the upcoming {{band_name}} show at:


{{venue_name}}

{{venue_city}}, {{venue_state}}

{{show_date}}


TOURING PARTY

{{touring_party}}


MERCH

Merch Advance Details: {{merch_manager_name}} (cc'd) {{merch_manager_email}} . {{merch_manager_phone}}.

DOS merch coordinator: {{merch_dos_name}} {{merch_dos_phone}} please provide him with venue merch seller contact info

 *** We request our set finish at least 20 minutes before final curfew so our merch can be available for purchase


TECHNICAL RIDER / INPUT LIST

Attached


RUN OF SHOW / SCHEDULE

Please provide us with the schedule including load in, soundcheck, performance start and end times. We request 3 hours from load in to the end of soundcheck.

Set length: {{set_length}}

TRANSPORTATION / PARKING

{{transportation_details}}


SOUND

We will bring our FOH engineer to mix the show. Please provide venue FOH contact so they can coordinate with our engineer.


LIGHTS

We will need the house LD to operate venue lights.


VIDEO

Please let us know if you have video capabilities, LED wall or projection mapping and if you have two cat 5/6 lines running from stage to FOH. This information will let us know if we are going to bring our VJ. Thanks!


HOSPITALITY

{{hospitality_preferences}}


ACCOMMODATION

Let us know if you have any deals with local hotels.


D.O.S. CONTACT

Let us know the day of show contact.


SETTLING

We require a settlement sheet the night of the show inclusive of all financials + box office totals with band member {{settling_member}}.


Let us know if you have any questions for us.

Thank you,

{{sender_name}}
