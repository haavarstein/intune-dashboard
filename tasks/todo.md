# Customer Health Overview sub-tab

## Goal
Single-screen tenant summary: total devices, refresh attention, failed apps, drifted software — for MSP customer-review meetings. Aggregates existing data sources via lightweight calls.

## Placement
- Leftmost Intune sub-tab.
- **Replaces Installed as the auto-loaded default on sign-in** (signalled by the user's MSP-focused audience). Installed becomes lazy-loaded on click.
- Easily reverted by changing one line in `onSignedIn`.

## Tasks
- [x] Overview subtab button (leftmost + active)
- [x] HTML: `<div id="intuneSubOverview">` with 4 KPI tiles + 2 side-by-side top-5 lists + "View all" jumps
- [x] Tab hint
- [x] Installed div gains `display:none`; Overview is default-visible
- [x] `onSignedIn` now calls `loadOverview()`
- [x] `switchSubtab` extended with Overview visibility + lazy-load hook
- [x] `loadOverview()` runs 3 parallel calls, each individually catch'd
- [x] All 4 KPI tiles + 2 top-5 lists wired
- [x] `[data-overview-jump]` click handler switches to Failed/Drift sub-tabs
- [x] README: sub-tab count 9→10, default tab Installed→Overview (3 places), new Overview entry, endpoint list note about the lightweight managedDevices variant
- [x] Canonical-facts scan run — no stale `nine sub-tabs` references remain

## Risks
- Defender KQL call fails on tenants without P2/E5 → entire load shouldn't break. Wrap each in `.catch` so partial data still renders.
- The hardware-lite call returns lastSync but not RAM. KPI #2 dedup needs (Win10 OR Stale), not low-RAM — accepted scope limitation.

## Verifiable success
1. Sign in → Overview is the first screen.
2. Three KPIs populate from the lightweight calls within ~2 seconds on a normal tenant.
3. Drift KPI shows "—" (not 0) and a "P2/E5 required" subtitle if the KQL 403s.
4. Top 5 lists render with link to drill into the underlying tab.
5. Default-tab change is one-line revertible.

## Review

**Net diff**: ~150 lines added to `index.html` (HTML + JS), ~10 lines to `README.md`. No new Graph scope; the lightweight managedDevices variant uses the existing `DeviceManagementManagedDevices.Read.All` scope.

**Behaviour change**: default sub-tab on sign-in moves from Installed to Overview. One-line revert: in `onSignedIn`, change `loadOverview()` back to `loadInstalledApps()` and swap the `active`/`display:none` on the two subtab buttons + divs. Captured in the README so users aren't surprised.

**Resilience**: each of the 3 fetches has its own `.catch` → null branch, with separate render paths. A tenant without Defender P2/E5 still gets devices + failed-apps tiles populated; the drift tile shows `—` and a "P2/E5 required" subtitle. Console gets a warn for the failed fetch.

**Reused module-scoped values** (all hoisted to script level — verified before commit): `graphGetAll`, `STALE_THRESHOLD_MS`, `DRIFT_KQL`, `titleCase`, `parseReport`. No new global state introduced beyond `overviewLoaded` and `overviewLoading`.

**Live verification needed**:
1. Sign out + back in → Overview is the first screen, loads within ~2 seconds on a small tenant.
2. Four KPIs populate with sensible values; sub-text fills in platform breakdown, stale count, total failed devices, scanned software count.
3. Top 5 lists populate with `View all →` links that switch to Failed and Drift tabs.
4. On a non-P2/E5 tenant: drift KPI shows `—` with "Defender P2/E5 required" subtitle; other tiles still work.
5. Other sub-tabs (Installed, Failed, etc.) still lazy-load correctly when clicked.
