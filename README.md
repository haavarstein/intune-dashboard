# The Intune Dashboard

A clean, client-side dashboard with four tabs:

1. **Local** — visualize Microsoft Intune uninstall registry exports from a CSV.
2. **Intune** — sign in with your Microsoft account and inspect your tenant live. Nine sub-tabs: Installed, Failed Install, Required Install, Required Uninstall, Hardware, Assignments, Remediation, Vulnerabilities (P2/E5), and Drift & Compliance (P2/E5).
3. **Analyze** — drop in Intune log files (IME, AgentExecutor, MSI verbose, etc.) and get an AI-powered diagnosis.
4. **Settings** — Claude API key and model selection for the optional AI features.

🔗 **Live:** [haavarstein.github.io/intune-dashboard](https://haavarstein.github.io/intune-dashboard/)

## Features

### Local tab (CSV)
- **Architecture detection** — separates 32-bit (WOW6432Node), 64-bit, and dual-registered apps
- **Smart deduplication** — collapses 32/64-bit duplicates into a single row
- **System component filtering** — hides hidden Windows components by default
- **HKLM vs HKCU** — distinguishes machine-wide from per-user installs
- **Uninstall commands** — one-click copy of standard and silent uninstall strings
- **Search & sort** — filter by name or publisher, sort any column

### Intune tab (Graph API)

Sign in once with MSAL — all nine sub-tabs share the same session.

**Failed Install** — apps with install failures across the fleet.
- Lists all apps with `FailedDeviceCount > 0`, sorted by failure count. `Update for*` driver/firmware apps are excluded.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Click an app to drill in to every device's install state (Application · Version · Platform · Device · User · State · Error · Last modified).
- **AI error analysis** *(optional)* — click an error code to get a diagnosis and remediation steps from Claude. Results are cached per error code in localStorage so repeat clicks are instant and free. Use the **↻ Re-analyze** button in the modal to force a fresh API call.

**Required Install** — Win32 apps assigned as *Required* to *All Devices*.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- Type to filter the list.
- `Update for*` driver/firmware apps are excluded for a cleaner audit view.

**Installed** *(default sub-tab)* — for any app, see the devices that report install status and the groups it's assigned to.
- Alphabetical list of apps that have at least one assignment (apps with no current assignment are excluded; data source is `mobileApps?$expand=assignments`, fully paginated — no 1000-app cap). Paginated 15 per page, with name/publisher search and a platform filter that defaults to *Windows*. `Update for*` driver/firmware apps are excluded.
- Click an app to drill in. The app name is a link that opens the app's blade in the Intune admin center in a new tab.
- **Assigned to** panel shows the assignment groups for the app, each tagged by intent (*Required* / *Available* / *Uninstall*). Special targets like *All Devices* and *All Users* are labeled as such; exclusion groups are marked `(exclusion)`.
- **Installed devices** table shows every device the install-status report returns: Device · User · Version · State · Platform · Last modified. The **State** dropdown defaults to whichever value starts with `installed` so you immediately see the install set; switch to *All states* to see failed, pending, etc.
- **⧉ Copy device names** copies the currently filtered list to the clipboard, newline-separated — paste straight into an Entra group, an exclusion list, or a Feature Update assignment. **⬇ Export CSV** downloads the same list (Device · User · Version · State · Platform · LastModified). Built for the use case of "give me the group of devices that have App X" — targeted upgrades and Feature Update exclusions.

**Required Uninstall** — apps assigned with intent *Uninstall* to a group.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Type to filter the list.

**Hardware** — managed-device inventory, framed for recycle/refresh planning and Windows 11 readiness.
- KPI tiles: ten clickable buckets — OS (Windows 10, Windows 11), RAM (4GB, 8GB, 16GB, 32+ GB), and storage (64GB, 128GB, 256GB, 512+ GB). Windows 10 matches build prefix `10.0.19`; Windows 11 matches `10.0.26`. **Click any tile to filter the table** to just those devices; click the active tile again, or hit **✕ Clear KPI** in the toolbar, to clear.
- Use cases: spot Windows 10 holdouts before end-of-support, find the low-RAM/low-storage devices that won't survive a Feature Update (or shouldn't get one), build refresh-budget shortlists, or pull a quick exclusion list of underspecced machines.
- RAM distribution donut chart for at-a-glance fleet composition.
- Filters for platform (defaults to *Windows*), RAM bucket, storage bucket, and manufacturer.
- Sortable table with device name, manufacturer, model, RAM, total/free storage, Windows version, and last check-in. Click a device name to open its Hardware blade in the Intune admin center in a new tab.
- `physicalMemoryInBytes` is fetched per device (the `managedDevices` list endpoint does not populate it), so the initial load is slower on large tenants.

**Vulnerabilities (P2/E5)** — software inventory from Microsoft Defender Vulnerability Management, surfaced via the Microsoft Graph Advanced Hunting API.

> ⚠️ **Licensing required.** This sub-tab queries Microsoft Defender Vulnerability Management data and **requires Microsoft Defender for Endpoint Plan 2 or Microsoft 365 E5** (or the standalone Defender Vulnerability Management add-on). Without one of these licenses the tab will load empty or error out — the rest of the dashboard works regardless. The "(P2/E5)" suffix in the tab label is a reminder of this requirement.

- **KPI tile**: total count of unique software components in the tenant. Click the tile to open the Defender portal's *Vulnerability management → Inventories → Software* page in a new tab.
- Sortable table with **Software**, **OS Platform**, **Vendor**, **Weaknesses** (distinct CVE count for that software), and **Exposed Devices** (distinct device count). Default sort is Weaknesses descending so the riskiest software floats to the top.
- Click any **Software** name to open the Defender portal's inventory page in a new tab for further investigation. (Defender doesn't expose a stable software ID via KQL, so the link goes to the inventory list rather than deep-linking to the specific row.)
- Type to filter across software name, vendor, and platform.
- Lazy-loaded: the query runs the first time you open the tab, then caches for the session. Use **↻ Refresh** to force a re-fetch.

**Drift & Compliance (P2/E5)** — fleet-wide software version drift, surfaced from Microsoft Defender Vulnerability Management via the Advanced Hunting API. Highlights software where devices are running mixed versions of the same product (e.g. .NET Desktop Runtime 8 alongside 9, Snagit across major versions).

> ⚠️ **Licensing required.** This sub-tab queries `DeviceTvmSoftwareInventory` and **requires Microsoft Defender for Endpoint Plan 2 or Microsoft 365 E5** (same constraint as Vulnerabilities). Devices must be Defender-onboarded to appear in the data.

- **KPI tiles**: count of software with > 10% drift, fleet drift average, total devices affected, and the single top-drifted software component.
- Sortable table with **Software**, **Vendor**, **Dominant Version**, **Drift %**, **Drifted Devices**, and **Versions Detected**. Drift % > 20% is highlighted. Default sort is Drift % descending.
- Click any **Software** name to open the Defender portal's inventory page for that software in a new tab — same deep-link pattern as the Vulnerabilities sub-tab, falling back to the inventory list when Defender doesn't expose a stable software ID.
- The **Distribution** column opens a Chart.js bar chart of the version histogram for that software — the dominant version is highlighted, the rest are the drift tail.
- Type to filter across software name and vendor. **⬇ Export CSV** downloads the current filtered view.
- Lazy-loaded: one KQL call against Defender on first open, cached for the session. Use **↻ Refresh** to force a re-fetch.
- Because data is grouped by *software name + vendor*, this catches the cross-Intune-app product-family drift that the install-status reports can't see — apps installed outside Intune, image-baked software, and major-version splits are all visible.

**Assignments** — group-centric reverse lookup. Pick an Entra group → see every policy targeting it, across seven types: apps, configuration profiles (legacy), settings catalog, compliance policies, PowerShell scripts, proactive remediation scripts, and Windows Update profiles (feature, quality, and driver).

- Type-ahead **group search** against `groups?$search="displayName:…"` (debounced 300ms, substring/token match). Pick a result to inspect.
- KPI tiles for the seven counts.
- Per-section tables show the policy name (linked to the relevant admin-center page), a type-specific column (intent for apps, type for configs, platform for settings catalog / compliance, run-as for PowerShell scripts, schedule for remediations, type for update profiles), the assignment filter ID if present, an *Excluded* badge if the assignment is an exclusion-group target, and the last-modified timestamp.
- Policy index is fetched once per session — 9 paginated Graph calls run in parallel on first tab open and cached. Per-endpoint failures (e.g. driver-update profiles on tenants without the licensing) are logged to the console but don't take down the rest of the load. Picking different groups after that is a client-side filter, no extra Graph traffic. Use **↻ Refresh** to invalidate the cache and re-fetch.
- Still out of scope: MAM/app-protection policies (different assignment shape), Autopilot profiles, endpoint security intents, and device/user-centric reverse lookup.

**Remediation** — proactive remediation scripts (`deviceHealthScripts`) and their schedules.

- Sortable table with **Script name**, **Publisher**, **Schedule**, **Assigned groups** (count), and **Last modified**. Default sort is Schedule with **Hourly** first, then **Daily**, then **Run once**, then **Unassigned**, tie-broken by script name A→Z.
- The **Schedule** column reads each script's assignment `runSchedule`. Scripts with multiple assignments at different cadences show a joined value (e.g. *Hourly, Daily*). Scripts with no assignments show *Unassigned*.
- Click any **Script name** to open the script's *Overview* blade (Intune admin center → *Devices → Scripts and remediations*) in a new tab. The link preserves the script's first-party vs tenant-uploaded distinction via the `isGlobalScript` flag from Graph.
- Type to filter across script name and publisher.
- Lazy-loaded: the call runs the first time you open the tab, then caches for the session. Use **↻ Refresh** to force a re-fetch.

### Analyze tab (log files)
- **Drop-zone upload** for one or more Intune log files (IME, AgentExecutor, MSI verbose, etc.)
- **Auto-trim** preprocessor — greps for error/failure/return-value lines and keeps ±15 lines of context around each match. Deduplicates overlapping windows. Cuts input tokens ~80% with no quality loss for triage. Toggle off to send the full log.
- **Haiku 4.5 by default** — cheapest, fastest, separate rate-limit bucket. Switch to Sonnet 4.6 in Settings for tougher logs.
- **Token usage shown** after each analysis (input/output and estimated USD cost) so you can track spend.
- **Session cost pill** — a small counter in the bottom-right shows total spend and call count for the current browser session across both error-code and log analyses. Click to reset. Resets automatically when the tab closes.

## Usage

### Local tab

1. Export the uninstall hive on a target machine (see snippet below)
2. Open the [dashboard](https://haavarstein.github.io/intune-dashboard/)
3. Drop or select the `Uninstall-Export.csv` file
4. Click any row for full details and uninstall commands

### Intune tab

1. Click the **Intune** tab and **Sign in with Microsoft**
2. A popup opens to `login.microsoftonline.com` — sign in with an account that has Intune read permissions
3. Consent to the requested scopes (see below)
4. The **Installed** sub-tab loads first, with the list of apps that have at least one assignment in your tenant
5. Click an app to see device-level install status, or switch to any other sub-tab (Failed Install, Hardware, Assignments, etc.)

Everything runs in your browser. CSV data never leaves your machine. Intune data is fetched directly from `graph.microsoft.com` to your browser — it does not pass through any server.

## Connecting to Intune

When you click **Sign in with Microsoft**, the dashboard uses MSAL.js to open a login popup against the multi-tenant endpoint (`login.microsoftonline.com/common`). The app is pre-registered in Azure AD, so you do **not** need to create your own app registration.

**Scopes requested (delegated, read-only):**

- `DeviceManagementManagedDevices.Read.All` — read managed device data
- `DeviceManagementApps.Read.All` — read Intune app data and install reports
- `Group.Read.All` — read group names to display the groups an app is assigned to (Installed sub-tab)
- `User.Read` — read your basic profile (to show your name in the UI)
- `ThreatHunting.Read.All` — run Defender Advanced Hunting KQL queries (Vulnerabilities sub-tab; requires Defender for Endpoint P2 or M365 E5 to return data)
- `DeviceManagementScripts.Read.All` — read Intune device health scripts (Remediation sub-tab) and PowerShell scripts (Assignments sub-tab)
- `DeviceManagementConfiguration.Read.All` — read configuration profiles, settings catalog policies, compliance policies, and Windows Update profiles (Assignments sub-tab)

**First-time consent.** On first sign-in, you (or your tenant admin, depending on tenant policy) must consent to the scopes above. If your tenant requires admin consent for these scopes and you are not an admin, sign-in will fail with an admin-consent-required error — ask your Intune admin to grant consent for the app. Existing users will see a one-time re-consent prompt whenever a new scope is added (most recently `DeviceManagementConfiguration.Read.All` for the expanded Assignments coverage).

**Token storage.** Access tokens are held in browser session storage by MSAL and refreshed silently. Click **Sign out** to clear them.

**What the dashboard calls:**

- `POST /beta/deviceManagement/reports/getAppsInstallSummaryReport` — apps overview (Failed Install filters server-side to `FailedDeviceCount > 0`; Installed fetches all apps)
- `POST /beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` — per-app device install status (used by both the Failed drill-in and the Installed devices view)
- `GET /beta/deviceAppManagement/mobileApps?$filter=...&$expand=assignments` — apps with assignments. Win32-filtered server-side for Required Install; all platforms (no `$filter`, paginated) for Required Uninstall *and* the Installed sub-tab, with client-side platform filtering.
- `GET /beta/deviceAppManagement/mobileApps/{id}?$expand=assignments` — assignments for the selected app in the Installed sub-tab
- `GET /beta/groups/{id}?$select=displayName,id` — group name lookup for each assignment target (Installed sub-tab)
- `GET /beta/deviceManagement/managedDevices?$select=...` — device inventory list (for the Hardware sub-tab)
- `GET /beta/deviceManagement/managedDevices/{id}?$select=physicalMemoryInBytes` — per-device RAM fetch (the list endpoint returns 0 for this field)
- `POST /v1.0/security/runHuntingQuery` — Defender Advanced Hunting KQL query against `DeviceTvmSoftwareInventory` and `DeviceTvmSoftwareVulnerabilities` (Vulnerabilities sub-tab) and against `DeviceTvmSoftwareInventory` grouped by `SoftwareName, SoftwareVendor, SoftwareVersion` (Drift & Compliance sub-tab)
- `GET /beta/deviceManagement/deviceHealthScripts?$expand=assignments` — proactive remediation scripts with their assignments (Remediation sub-tab, reused by Assignments sub-tab)
- `GET /v1.0/groups?$search="displayName:…"` — Entra group type-ahead search (Assignments sub-tab; sent with `ConsistencyLevel: eventual` header)
- `GET /beta/deviceManagement/deviceConfigurations?$expand=assignments` — configuration profiles (legacy) with their assignments (Assignments sub-tab)
- `GET /beta/deviceManagement/deviceCompliancePolicies?$expand=assignments` — compliance policies with their assignments (Assignments sub-tab)
- `GET /beta/deviceManagement/configurationPolicies?$expand=assignments` — settings catalog policies (Assignments sub-tab)
- `GET /beta/deviceManagement/deviceManagementScripts?$expand=assignments` — PowerShell scripts (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsFeatureUpdateProfiles?$expand=assignments` — Windows Feature Update profiles (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsQualityUpdateProfiles?$expand=assignments` — Windows Quality Update profiles (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsDriverUpdateProfiles?$expand=assignments` — Windows Driver Update profiles (Assignments sub-tab; requires Autopatch licensing in some tenants — silently skipped if 403)

These are the same endpoints the Intune admin center uses for its "Apps install status" and "Device install status" views.

## AI error analysis (optional)

If you add a Claude API key under the **Settings** tab, error-code cells in the device table become clickable. Clicking sends the app + device + error context to the Claude API and shows a structured diagnosis (what the error means, likely cause, remediation steps) in a modal.

Analyses are cached per `errorCode + model` in `localStorage`. Re-clicking the same error code renders instantly from cache with a **Cached** badge — no API call, no tokens spent. Click **↻ Re-analyze** in the modal header to force a fresh response (useful if you change models or want to retry).

**Models available:**

| Model | Price (per MTok) | Approx. cost per click | Good for |
| --- | --- | --- | --- |
| Haiku 4.5 *(default)* | $1 / $5 | ~$0.0025 | Most triage; cheapest, separate rate-limit bucket |
| Sonnet 4.6 | $3 / $15 | ~$0.0075 | Escalate for longer logs or harder root-cause work |
| Opus 4.7 | $5 / $25 | ~$0.0125 | Reserve for stuck cases |

**A note on model choice.** Haiku 4.5 is the default for everything — it's the cheapest current-generation model and uses a separate rate-limit bucket from Sonnet/Opus, so heavy Sonnet usage elsewhere won't throttle your dashboard. For most error codes and routine log triage, Haiku is enough. Escalate to **Sonnet 4.6** when Haiku misses something — its real strength is correlating timestamps across long IME logs and isolating root cause from noise. Reserve **Opus 4.7** for cases where Sonnet gives up; its new tokenizer uses up to 35% more tokens for the same input, so the effective cost gap is wider than headline pricing suggests. The biggest cost lever regardless of model is **auto-trim** (the toggle on the Analyze tab) — it greps for error/return-value lines plus surrounding context and typically cuts input tokens 80%+ with no quality loss.

**Where the API key lives.** The key is stored in your browser's `localStorage` and sent only to `api.anthropic.com`. The request uses the `anthropic-dangerous-direct-browser-access` header, which means **the key is readable by anyone who can open DevTools on this page**. This is fine for a personal tool you run yourself. **Do not paste an API key into a shared or public deployment.** If you want to share the tool with a team, route the call through a backend (Cloudflare Worker, Vercel function, etc.) that holds the key server-side.

## Exporting the registry (for the Local tab)

Run this PowerShell snippet on a target machine to generate the CSV:

```powershell
$paths = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$desktop = [Environment]::GetFolderPath("Desktop")
Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName } |
  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate,
                UninstallString, QuietUninstallString, SystemComponent,
                PSChildName, @{n='RegistryPath';e={$_.PSPath -replace 'Microsoft.PowerShell.Core\\Registry::',''}} |
  Export-Csv -Path "$desktop\Uninstall-Export.csv" -NoTypeInformation -Encoding UTF8
```

## Tech

Single-file HTML. No build step. [PapaParse](https://www.papaparse.com/) for CSV parsing, [MSAL.js](https://github.com/AzureAD/microsoft-authentication-library-for-js) for Microsoft sign-in, Microsoft Graph beta endpoints for Intune data, optional [Claude API](https://docs.claude.com/en/api/overview) for error analysis. All via CDN. Inter font.

## License

MIT — see [LICENSE](LICENSE).
