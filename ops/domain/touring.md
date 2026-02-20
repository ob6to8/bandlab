---
domain: touring
triggers: [tour, run, one-off, routing, rider, tech rider, hospitality rider, stage plot, input list, crew]
---

# Touring

Tour structure, rider management, and logistics planning.

## Tours, Runs, and One-Offs

- **Tour** — the top-level grouping for a period of shows (e.g., "Spring 2026 Tour")
- **Run** — a consecutive sequence of shows within a tour, typically a weekly leg with shared logistics (same vehicle, same crew, connected routing)
- **One-off** — a standalone show that belongs to a tour but not to any run (e.g., a festival appearance between runs)

Logistics planning happens at the run level (vehicle rental, lodging blocks, routing). Creative/strategic planning happens at the tour level (crew assignments, production design, rider updates).

## The Rider

A **rider** is the document sent to venues during advancing that specifies what the artist requires for their performance. It has two parts:

### Technical Rider
Covers the production requirements:
- **Backline** — what the venue must provide on stage. Only lists what the venue provides, never what the band carries.
- **Input list** — channel-by-channel listing of every audio source, with stage position.
- **Stage plot** — visual diagram of performer positions, equipment placement, and cable runs.
- **Sound/FOH section** — console requirements, snake routing, drive line specs, support act changeover protocol.
- **Monitoring** — IEMs, wedges, or both. Who controls the mix, what the venue provides.
- **Power** — quad box locations and power requirements on stage.
- **Video** — LED wall, projection, ethernet/HDMI drops.
- **Crew** — who the band is bringing.
- **House staff** — what venue staff the band needs.

### Hospitality Rider
- **Dressing rooms** — private space for the band.
- **Food/drink** — catering, buyouts, snacks, beverages.
- **Accommodation** — hotel deals or provided lodging.
- **Settlement** — who handles payment, what entity checks are written to.

### Rider Maintenance

Riders drift over time. Common problems:
- Multiple versions for different scenarios that diverge when updated independently
- Internal production details leaking into the external rider
- Outdated technical details persisting across tours

**Recommended approach:** Maintain rider content as modular blocks tagged with conditions, assembled per scenario. See `ops/systems/rider-system.md` in the private repo for the implementation.

### Rider Artifacts

Final assembled riders for email attachment live in `org/touring/assets/`. Convention:
- **Directory name** describes the rider variant: `Dirtwire Rider - Spring 2026 (Club - No LD)`
- **File inside** is named generically for attachment: `Dirtwire Rider - Spring 2026.pdf`

This way the attached file reads cleanly in the recipient's inbox while the directory name provides context for the sender.

### Internal vs External

| What | Where | Audience |
|---|---|---|
| Rider text (what venue provides) | `rider-blocks.yaml` → assembled files in `org/touring/assets/` | Venues |
| Gear inventory, signal flow, personnel | `org/touring/tours/<tour>/production.md` | Band/crew only |
| Rider source content (blocks) | `org/touring/advancing/source/riders/rider-blocks.yaml` | Agent/band |
