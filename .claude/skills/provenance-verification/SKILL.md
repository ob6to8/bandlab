Verify that all data traces back to source documents.

## Steps

1. Run `./bandlab-cli provenance-verification`
2. Review the coverage report:
   - Shows with `_provenance` blocks (should be 100%)
   - Field coverage percentage
   - Missing source files
   - Registry source coverage (people.json, venues.json)
3. For any errors (missing source files, broken paths), investigate and fix
4. **Spot-check content accuracy**: Pick 2-3 shows that have source PDFs, read the PDF, and compare extracted values (guarantee, door_split, ages, etc.) against what show.json claims. Flag any mismatches.
5. Report the coverage summary and any discrepancies found in the spot-check
