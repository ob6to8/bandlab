---
domain: contracts
triggers: [contract, deal memo, guarantee, settlement, door split, merch cut, radius clause, offer, GBOR, NBOR]
---

# Contracts and Settlement

Deal structure, contract terms, and post-show financial reconciliation.

## Contracts / Deal Memos

The contract (or "deal memo") establishes the legal and financial terms for a show. Key fields:
- **Guarantee** — flat payment amount
- **Door split / percentage** — percentage of ticket revenue (vs guarantee, plus guarantee, or from dollar one)
- **Merch cut** — venue's take on merchandise sales
- **Ages** — all-ages, 18+, 21+
- **Radius clause** — restrictions on nearby shows within a time window
- **Cancellation terms** — what happens if either party cancels
- **Venue/production contacts** — names and contact info for advancing
- **Promoter** — the entity buying the show

Contract data is extracted into structured summaries but requires human approval before being treated as trusted data. The contract PDF is the primary source; the summary is derived.

## Settlement

Post-show financial reconciliation. The settlement sheet includes:
- Gross box office receipts (ticket sales)
- Deductions (taxes, facility fees, venue expenses, support act costs)
- Net receipts
- Artist guarantee vs percentage calculation (whichever is greater, per contract)
- Merch settlement (gross sales minus venue cut)
- Final payment amount

Settlement happens the night of the show. The artist's designated settlement contact reviews the numbers with the venue/promoter.

## Deal Types

See also `glossary.md` for term definitions.

| Term | Meaning |
|---|---|
| **Guarantee vs %** | Artist takes whichever is greater |
| **PLUS** | Guarantee + bonus %, after expenses |
| **GBOR** | Gross Box Office Receipts — total revenue before deductions |
| **NBOR** | Net Box Office Receipts — revenue after expenses |
| **PP** | Promoter Profit |
| **Door** | Can be gross or net (varies by contract) |
