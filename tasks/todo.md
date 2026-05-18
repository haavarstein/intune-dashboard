# Hardware: stale-device + Windows 10 post-EOS surfacing

## Goal
Surface two refresh/lifecycle problems that the Intune portal hides:
1. **Stale devices** — managed devices that haven't checked in for 90+ days. Often the long tail of unmaintained hardware that should be retired/wiped/refreshed.
2. **Windows 10 post-EOS** — Windows 10 mainstream support ended 2025-10-14. The fleet count is the urgency number for refresh planning.

Plus add a CSV export so a filtered tile selection (e.g. "show Win 10 devices") can be dropped straight into an Entra group for refresh batches.

## Tasks
- [x] Stale 90+ days tile added between Win11 and 4GB RAM
- [x] Windows 10 tile sub-text now reads "Past EOS · Oct 2025"
- [x] `isStale` helper + 90-day threshold constant
- [x] Filter integration: `kind === 'stale'` branch in `filterHw`
- [x] `hwTileMap` extended with `hwStaleTile: 'stale:1'`
- [x] Export CSV button + handler
- [x] Updated Hardware tab hint to mention new features
- [x] README Hardware section updated (11 tiles, EOS framing, export)
- [x] Canonical-facts scan: no stale "ten KPI buckets" left
- [x] Bonus pre-existing bug fix: lifted `escCsv` to module scope (was function-local inside `exportInstalledCSV`; Drift and Hardware CSV exports would have ReferenceError'd otherwise)

## Notes
- Stale threshold: 90 days (a single hard line in v1; we can expose 30/60/90 dropdowns later if asked)
- Date math: use `Date.now() - 90 * 24 * 3600 * 1000` against the parsed `lastSyncDateTime`
- Devices with empty `lastSync` (never synced): treat as stale? — Yes, they're at least as suspicious as 90+ days
- No new endpoint or scope needed — `lastSyncDateTime` already in the existing `$select`

## Verifiable success
1. Stale tile renders with a count > 0 on any tenant with old devices
2. Click stale tile → table shows only those devices
3. Click again → un-filters
4. ⬇ Export CSV downloads the currently filtered rows
5. Win10 tile reads "Past EOS · Oct 2025" subtext

## Review

**Net diff**: ~30 lines added to `index.html`, ~3 lines changed in `README.md`. No new endpoints, no new scopes. The `lastSyncDateTime` field was already in the existing `$select`, so the stale detection is free.

**Design**:
- Single stale threshold (90 days) in v1. If 30/60/90 segmentation becomes useful, expose as a dropdown later.
- Never-synced devices (`lastSync === ''`) count as stale — they're at least as suspicious as 90+ days idle.
- CSV export reuses the toolbar pattern from Installed sub-tab; same `escCsv` helper (now module-scoped).

**Pre-existing bug caught**: `escCsv` was declared `const` inside `exportInstalledCSV()`, but referenced from `exportDriftCSV()` at module scope. Drift CSV export would have thrown `ReferenceError: escCsv is not defined` whenever invoked. Lifted to module scope; removed the duplicate. Fix shipped in this same commit because finding it while writing the Hardware export means I own it now.

**Live verification needed**:
1. Hardware → Stale 90+ days tile shows a count.
2. Click tile → table filters to stale devices only.
3. Click again → un-filters.
4. Click ⬇ Export CSV with stale tile active → downloads `hardware-inventory.csv` with just those rows.
5. Click Win10 tile → filters to Win10 devices; sub-text reads "Past EOS · Oct 2025".
6. Sanity check Drift's CSV export — should now work too.
