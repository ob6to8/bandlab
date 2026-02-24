Check that documentation accurately describes the system.

## Steps

1. Run `./bandlab-cli doc-check`
2. Review the output for any issues:
   - **Skills sync**: skill dirs that are missing from or extra in the CLAUDE.md skills table
   - **Backing scripts**: skills with listed scripts that don't exist
   - **Ops sync**: ops files that are missing from or extra in the CLAUDE.md ops table
   - **Submodule status**: uncommitted bandlab/ changes or dirty submodule ref
   - **Schema vs reality**: show.json fields not in the documented schema
3. For any issues found, investigate and fix:
   - Update CLAUDE.md tables if skills or ops are out of sync
4. Go deeper than the script — spot-check that:
   - `bandlab/CLAUDE.md` schema fields match actual show.json fields in a few shows
   - `ops/systems/provenance-plan.md` phase checkboxes match reality
5. Re-run `./bandlab-cli doc-check` to confirm all clear
