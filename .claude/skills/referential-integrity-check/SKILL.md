Run the referential integrity check and report results.

## Steps

1. Run `./bandlab-cli referential-integrity-check`
2. Summarize the results:
   - Total checks, errors, warnings
   - List any **errors** (broken references, missing files) — these need fixing
   - List any **warnings** (null promoters, etc.) — note whether they're expected
3. If there are errors, investigate each one and suggest a fix
4. If the check is clean, just report the summary line
