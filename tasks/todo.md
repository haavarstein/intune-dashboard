# Patch My PC filter (Installed + Failed Install)

## Goal
Checkbox in both Installed and Failed Install app pickers to include/exclude apps created by Patch My PC (PMPC). PMPC apps are identified by `notes` starting with `PmpAppId`. Default: **exclude** (checkbox unchecked).

## Tasks
- [x] Shared module-scope `pmpcAppIds` Set + `ensurePmpcAppIdsLoaded()` lazy loader + `populatePmpcFromMobileApps()` helper
- [x] `loadInstalledApps()` populates the Set from its existing mobileApps fetch (no extra Graph call when Installed loads first)
- [x] `loadApps()` (Failed) awaits `ensurePmpcAppIdsLoaded()` in parallel with its report fetch via `Promise.all`
- [x] PMPC checkbox in both `app-picker-bar`s
- [x] Filter logic added to `applyInstalledAppFilter()` and `applyAppFilter()`
- [x] Onchange listeners on both checkboxes wired
- [x] README: both sub-tab entries updated, endpoint list note added for `?$select=id,notes`

## Verifiable success
1. Sign in → land on Installed → PMPC apps absent from the picker by default.
2. Check "Include Patch My PC" → PMPC apps appear.
3. Same behavior in Failed Install.
4. State persists when navigating to a selected app and back — checkbox state stays.

## Review

**Net diff**: ~50 lines added to `index.html` (PMPC shared infra + checkboxes + filter logic + listeners), ~5 lines to `README.md`. No deletions, no existing-behavior changes.

**Design notes**:
- One shared `pmpcAppIds` Set. Both tabs read from it. The Installed loader populates it for free from its already-fetched mobileApps response; the Failed loader triggers a dedicated lightweight `?$select=id,notes` fetch only if no other path has populated it yet (cached via `pmpcAppIdsPromise` to deduplicate concurrent calls).
- No new scope (`DeviceManagementApps.Read.All` already covers `mobileApps`).
- Filter is purely client-side — the Set is built once per session and reused, so toggling the checkbox is instant.

**Canonical-facts scan run** (per lessons.md): sub-tab count unchanged, scope count unchanged, default sub-tab unchanged, no stale claims. README endpoint line for `mobileApps` updated to mention the new `$select=id,notes` variant.

**Live verification needed**:
1. Sign in → Installed sub-tab loads → PMPC apps (those with `notes` starting `PmpAppId`) are hidden by default.
2. Tick "Include Patch My PC" → they appear.
3. Failed Install → same behavior. Note: Failed Install adds a parallel `mobileApps?$select=id,notes` call on first load; should still be fast (<1s on most tenants).
4. Toggle checkbox repeatedly — instant filter, no Graph traffic.
