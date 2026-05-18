# Detection Rule Inspector

## Goal
Click any selected app in Installed or Failed sub-tab → modal showing exactly what Intune's detection rule checks for. Directly attacks Win32 pain points ("Download Pending", "no longer detected", "detection failed") — debugging these always boils down to "what is the detection rule, and why doesn't it match this device?"

## Scope
- IN: Win32 LoB (`win32LobApp`) — MSI ProductCode, File/Folder, Registry, PowerShell Script rules
- IN: Windows MSI LoB (`windowsMobileMSI`) — `productCode` + `productVersion` from the app object
- IN: macOS LoB (`macOSLobApp`) — `bundleId` + version fields
- IN: Decode + show PowerShell script content (base64 → UTF-8)
- OUT: iOS / Android / Store / Office Suite — show "no detection rule" message
- OUT: Edit/upload (read-only by design)

## Tasks
- [x] Modal HTML next to existing `#modal` — separate `#detModal`, same CSS classes
- [x] "🔍 Detection rule" button in Installed sub-tab's `.selected-app` section
- [x] Same button in Failed sub-tab's `.selected-app` section
- [x] JS: `openDetectionRulesModal(app)` — fetches `mobileApps/{id}`, dispatches on `@odata.type`
- [x] Formatters per rule type (Win32 registry, file, MSI product code, PowerShell script) + Windows MSI LoB + macOS LoB
- [x] Operation-code → human label map (`WIN32_OP_LABEL`)
- [x] Base64-decode PowerShell scripts to UTF-8 via TextDecoder
- [x] Graceful "not applicable for this app type" message
- [x] Close button + backdrop-click close
- [x] README: mentioned in Installed + Failed entries, plus new endpoint line

## Graph endpoint
- `GET /beta/deviceAppManagement/mobileApps/{id}` — returns the app with inline `rules` (polymorphic via `@odata.type`)
- Already-granted scope `DeviceManagementApps.Read.All` — no new scopes needed
- Already-existing endpoint in dashboard — no new entry in README's API list

## Risks
- The `rules` collection vs the legacy `detectionRules` field — handle both, prefer `rules` filtered to `ruleType === 'detection'`. Older apps may only have `detectionRules`.
- PowerShell script content may not always be base64 (Microsoft has been inconsistent here). Try base64 decode; fall back to raw value on failure.

## Verifiable success
1. Pick a Win32 app with MSI ProductCode detection → modal shows the GUID and version operator clearly.
2. Pick one with File/Folder detection → shows path + filename + comparison.
3. Pick one with Registry detection → shows key/value path + operation.
4. Pick one with a PowerShell script → shows the decoded script content (not the base64 blob).
5. Pick a Store app or Office Suite → friendly message, no error.

## Review

**Net diff**: ~140 lines added to `index.html` (HTML modal + buttons + JS module), ~6 lines to `README.md`. No changes to existing functions.

**Reused**: the existing `.modal-backdrop`/`.modal`/`.modal-header`/`.modal-body` CSS classes (separate `#detModal` id, no JS collision with AI modal). The existing `selectedApp` module-scoped variable, set by both Installed and Failed sub-tabs.

**No new scope, no new endpoint family**: uses the already-listed `GET /beta/deviceAppManagement/mobileApps/{id}` (without `$expand` — `rules` is inline). Documented as a separate endpoint line in README for clarity even though the URL is the same minus parameters.

**Canonical-facts scan run** (per `lessons.md`): sub-tab count, scope count, default sub-tab all unchanged. No stale claims found.

**Live verification needed**:
1. In Installed → pick a Win32 LoB app → click 🔍 Detection rule → modal shows MSI ProductCode / File / Registry / PowerShell rule(s).
2. Pick one with a PowerShell detection script → script content is decoded and readable, not raw base64.
3. Pick a Windows MSI LoB app → modal shows ProductCode + ProductVersion.
4. Pick a Microsoft Store app or Office Suite → modal shows the "not applicable for this app type" message gracefully.
5. Failed sub-tab → same button → same modal behavior.
6. Close via × button and via backdrop click.
