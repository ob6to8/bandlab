---
domain: production
triggers: [foh, sound, monitoring, stage, signal, console, snake, IEM, wedge, backline, drive line, stage box, submix]
---

# Production

Live sound, signal flow, monitoring, and stage setup concepts.

## FOH (Front of House)

The FOH engineer mixes the live sound from a position in the audience area. Two scenarios:

### House FOH
The venue provides the mixing console and engineer. The band's audio comes through the venue's system. The rider must specify everything the venue needs to know about routing, monitoring, and signal flow.

### Carried FOH
The band tours with their own FOH engineer and console. This significantly changes the rider:
- Venue provides less (fewer mics, stands — the engineer carries specialized equipment)
- Sound section describes the carried console and how it integrates with the venue's system (snake routing, drive lines, console switching for support acts)
- Monitoring details may be simplified (engineer handles it internally)
- House staff requirements change (need someone for changeover/drive line swap, not a full FOH engineer)

## Signal Flow

### Stage to FOH
Audio signals travel from stage to the FOH position via snakes (bundled cable runs):
- **Analog snakes** — XLR cable bundles, traditional
- **Digital snakes** — Cat5/6 ethernet carrying digital audio (e.g., Dante, Waves SoundGrid). Lighter, longer runs, but require compatible gear on both ends
- **Stage box / IO rack** — the box on stage where individual cables plug in. Converts to the snake format (analog or digital) for the run to FOH

### Drive Lines
The connection from the mixing console (or stage rack) to the venue's speaker processor. Can be AES (digital) or analog. Critical rule: drive lines should hit the processor directly, not pass through the house console, to maintain signal integrity.

### Console Switching
When a band carries their own console, support acts typically use the house console. Between sets, the system must switch from the house console to the headliner's console. A **console switcher** makes this seamless. Without one, drive lines must be physically swapped.

## Monitoring

### IEMs (In-Ear Monitors)
Custom earpieces with personal mixes. Band members control their own mix levels, often via Ableton submixes, hardware controllers, or console apps. Self-contained IEM rigs mean the venue doesn't need to provide wedges.

### Wedges (Floor Monitors)
Traditional stage monitors — speakers on the floor angled up at performers. Require a monitor engineer or monitor sends from FOH. Still commonly needed for guest performers who don't have their own IEMs.

### Submix
A grouped mix of multiple channels sent as a single feed. Example: percussion + guest channels grouped into one stereo or mono send to the band's IEM rig. Allows the band to control the overall level of "everything from the console" without needing individual channel control.
