# The Intune Dashboard

A clean, client-side dashboard with four tabs:

1. **Local** — visualize a Windows uninstall-registry export from a single machine. Accepts a PowerShell-generated CSV *or* the `.reg` files from an Intune **Collect diagnostics** bundle (drop one or both `.reg` files at once).
2. **Intune** — sign in with your Microsoft account and inspect your tenant live. Ten sub-tabs: Overview, Installed, Failed Install, Required Install, Required Uninstall, Hardware, Assignments, Remediation, Vulnerabilities (P2/E5), and Drift & Compliance (P2/E5).
3. **Analyze** — drop in Intune log files (IME, AgentExecutor, MSI verbose, etc.) and get an AI-powered diagnosis.
4. **Settings** — manage a list of customers (for MSP multi-tenant workflows), configure the Claude API key, and pick the model used for the optional AI features.

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

Sign in once with MSAL — all ten sub-tabs share the same session.

**Overview** *(default sub-tab on sign-in)* — single-screen tenant health summary, framed for MSP customer-review meetings.

- Four KPI tiles: **Managed devices** (with top-3 platform breakdown), **Needing attention** (Win10 holdouts + stale-90d, deduplicated), **Apps with failures** (count + total failed-device-count subtitle), and **Drifted software** (components with >20% drift; requires Defender P2/E5).
- **Top 5 failing apps** list + **Top 5 drifted software** list side-by-side, each with a "View all →" link that jumps to the underlying Failed Install or Drift & Compliance sub-tab.
- Loads on sign-in. Three parallel lightweight calls — a `managedDevices` list with only `id,osVersion,operatingSystem,lastSyncDateTime` (no per-device RAM fan-out), the existing `getAppsInstallSummaryReport`, and the Defender drift KQL — each individually catch'd so one failure (e.g. P2/E5 not licensed) doesn't break the other tiles.
- Tenants without Defender P2/E5: the Drift tile and list show `—` with a "P2/E5 required" subtitle; everything else still renders.

**Failed Install** — apps with install failures across the fleet.
- Lists all apps with `FailedDeviceCount > 0`, sorted by failure count. `Update for*` driver/firmware apps are excluded.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Click an app to drill in to every device's install state (Application · Version · Platform · Device · User · State · Error · Last modified).
- **Include Patch My PC** checkbox (above the app list, default unchecked) — apps created by Patch My PC Publisher are detected by their `notes` field starting with `PmpAppId` and hidden from the list by default, since they typically dominate the volume of assigned-and-failed apps in larger tenants. Tick the box to include them.
- **AI error analysis** *(optional)* — click an error code to get a diagnosis and remediation steps from Claude. Results are cached per error code in localStorage so repeat clicks are instant and free. Use the **↻ Re-analyze** button in the modal to force a fresh API call.
- **🔍 Detection rule** button in the selected-app header — opens a modal showing exactly what Intune is checking for on each device (MSI ProductCode + version operator, file/folder path + version comparison, registry key + value match, or the full PowerShell detection script — base64-decoded). Read-only. Most failed-install threads on r/Intune ultimately reduce to "what does the detection rule check, and why doesn't it match?" — this answers that without leaving the dashboard.

**Required Install** — Win32 apps assigned as *Required* to *All Devices*.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- Type to filter the list.
- `Update for*` driver/firmware apps are excluded for a cleaner audit view.

**Installed** — for any app, see the devices that report install status and the groups it's assigned to.
- Alphabetical list of apps that have at least one assignment (apps with no current assignment are excluded; data source is `mobileApps?$expand=assignments`, fully paginated — no 1000-app cap). Paginated 15 per page, with name/publisher search and a platform filter that defaults to *Windows*. `Update for*` driver/firmware apps are excluded.
- **Include Patch My PC** checkbox (above the app list, default unchecked) — same behavior as Failed Install: PMPC-created apps (detected via `notes` starting with `PmpAppId`) are hidden by default and surface when the box is ticked.
- Click an app to drill in. The app name is a link that opens the app's blade in the Intune admin center in a new tab.
- **Assigned to** panel shows the assignment groups for the app, each tagged by intent (*Required* / *Available* / *Uninstall*). Special targets like *All Devices* and *All Users* are labeled as such; exclusion groups are marked `(exclusion)`.
- **Installed devices** table shows every device the install-status report returns: Device · User · Version · State · Platform · Last modified. The **State** dropdown defaults to whichever value starts with `installed` so you immediately see the install set; switch to *All states* to see failed, pending, etc.
- **⧉ Copy device names** copies the currently filtered list to the clipboard, newline-separated — paste straight into an Entra group, an exclusion list, or a Feature Update assignment. **⬇ Export CSV** downloads the same list (Device · User · Version · State · Platform · LastModified). Built for the use case of "give me the group of devices that have App X" — targeted upgrades and Feature Update exclusions.
- **🔍 Detection rule** button in the selected-app header — same Detection Rule Inspector as on Failed Install. Shows the per-app detection logic that Intune evaluates on every device: MSI ProductCode + version operator, file/folder + version comparison, registry key + value match, or the full PowerShell detection script (base64-decoded). Supports Win32 LoB, Windows MSI LoB, and macOS LoB; other types show a "not applicable for this app type" message.
- **🗑 Delete from Intune** button in the selected-app header — permanently removes the app from this tenant via Graph `DELETE /deviceAppManagement/mobileApps/{id}`. Requires typing the exact app name to confirm (case-sensitive) **and** a free-text justification (sent base64-encoded as the `x-msft-approval-justification` header — recorded in the Intune audit log; required by tenants with multi-admin approval / privileged operations, ignored elsewhere). Existing installs on devices are not uninstalled, but Intune stops managing and reporting on the app. Delete is one of two write actions in the dashboard (the other is the MAA approver email below — everything else is read-only). Requires the `DeviceManagementApps.ReadWrite.All` scope (admin consent may be needed in stricter tenants). **Multi-admin approval:** if the tenant requires a second admin to approve app deletes, the request enters a pending queue (HTTP 412 with an approval code) — the dashboard shows the approval code and tells you to have an approver act on the request in *Tenant administration → Multi Admin Approval → Access requests*. Once approved there, Intune executes the delete on its own; the dashboard does not need to retry. (HTTP 409 "active Approval Request already exists" is treated the same — request is already pending; nothing to do but wait for approval.) **Auto-notify approvers:** when the customer has an approver list configured in Settings → Customers, the dashboard sends an email from your mailbox to those approvers at the moment of submission — closing the gap that Intune itself doesn't send notifications when MAA requests are created. Uses the `Mail.Send` scope and Graph `POST /v1.0/me/sendMail`. Empty approver list = no email sent. **Live status polling:** after submission, the modal polls `GET /beta/deviceManagement/operationApprovalRequests/{id}` every 30 s and updates a status row inline — *⏳ Pending → ✓ Approved by <name> (with approver note) → picker auto-refreshes* — or shows *✗ Rejected by <name>* with the reason. Uses the existing `DeviceManagementConfiguration.Read.All` scope. Polling stops on terminal state or when you close the modal.

**Required Uninstall** — apps assigned with intent *Uninstall* to a group.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Type to filter the list.

**Hardware** — managed-device inventory, framed for recycle/refresh planning, Windows 11 readiness, and post-EOS Windows 10 cleanup.
- KPI tiles: eleven clickable buckets — OS (Windows 10 [Past EOS · Oct 2025], Windows 11), **Stale 90+ days** (no check-in for 90 days+; includes never-synced devices), RAM (4GB, 8GB, 16GB, 32+ GB), and storage (64GB, 128GB, 256GB, 512+ GB). Windows 10 matches build prefix `10.0.19`; Windows 11 matches `10.0.26`. **Click any tile to filter the table** to just those devices; click the active tile again, or hit **✕ Clear KPI** in the toolbar, to clear.
- **⬇ Export CSV** in the toolbar downloads the currently filtered table — combine with a tile selection (e.g. *Windows 10*) to drop the result straight into an Entra group for refresh batches.
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

1. Get an uninstall-registry export from a target machine. Two options:
   - **PowerShell** (CSV, includes HKLM 32/64-bit *and* HKCU) — run the snippet at the bottom of this README on the target machine.
   - **Intune Collect diagnostics** (REG, HKLM only) — trigger the *Collect diagnostics* remote action on a device, extract the ZIP, and use the files numbered `(18) RegistryKey HKLM_Software_…_Uninstall export.reg` and `(21) RegistryKey HKLM_SOFTWARE_WOW6432Node_…_Uninstall export.reg`. Note: Intune diagnostics doesn't export the per-user HKCU hive, so the *Per-user* tile will show 0.
2. Open the [dashboard](https://haavarstein.github.io/intune-dashboard/)
3. Drop or select the file(s) — `.csv` or one-or-more `.reg`. The **↻ Replace / add files** link in the toolbar lets you drop more `.reg` files later to merge.
4. Click any row for full details and uninstall commands

### Intune tab

1. Click the **Intune** tab and **Sign in with Microsoft**
2. A popup opens to `login.microsoftonline.com` — sign in with an account that has Intune read permissions
3. Consent to the requested scopes (see below)
4. The **Overview** sub-tab loads first, with the tenant health summary
5. Click any other sub-tab — Installed, Failed Install, Hardware, Assignments, etc. — to drill in

Everything runs in your browser. CSV data never leaves your machine. Intune data is fetched directly from `graph.microsoft.com` to your browser — it does not pass through any server.

## Connecting to Intune

When you click **Sign in with Microsoft**, the dashboard uses MSAL.js to open a login popup against the multi-tenant endpoint (`login.microsoftonline.com/common`). The app is pre-registered in Azure AD, so you do **not** need to create your own app registration.

**Scopes requested (delegated):**

- `DeviceManagementManagedDevices.Read.All` — read managed device data
- `DeviceManagementApps.Read.All` — read Intune app data and install reports
- `DeviceManagementApps.ReadWrite.All` — **write scope** for deleting apps from Intune (Installed sub-tab → 🗑 Delete from Intune)
- `Mail.Send` — **write scope** to send the MAA approver notification email from your own mailbox at the moment a delete is submitted; never used for anything else
- `Group.Read.All` — read group names to display the groups an app is assigned to (Installed sub-tab)
- `User.Read` — read your basic profile (to show your name in the UI)
- `ThreatHunting.Read.All` — run Defender Advanced Hunting KQL queries (Vulnerabilities sub-tab; requires Defender for Endpoint P2 or M365 E5 to return data)
- `DeviceManagementScripts.Read.All` — read Intune device health scripts (Remediation sub-tab) and PowerShell scripts (Assignments sub-tab)
- `DeviceManagementConfiguration.Read.All` — read configuration profiles, settings catalog policies, compliance policies, and Windows Update profiles (Assignments sub-tab)

Two write scopes total — `DeviceManagementApps.ReadWrite.All` and `Mail.Send` — everything else is read-only. Stricter tenants may require admin consent for the write scopes; if you can't consent yourself, an Intune admin needs to grant it before 🗑 Delete from Intune and the approver-notification email will work.

**First-time consent.** On first sign-in, you (or your tenant admin, depending on tenant policy) must consent to the scopes above. If your tenant requires admin consent for these scopes and you are not an admin, sign-in will fail with an admin-consent-required error — ask your Intune admin to grant consent for the app. Existing users will see a one-time re-consent prompt whenever a new scope is added (most recently `DeviceManagementConfiguration.Read.All` for the expanded Assignments coverage).

**Token storage.** Access tokens are held in browser session storage by MSAL and refreshed silently. Click **Sign out** to clear them.

**What the dashboard calls:**

- `POST /beta/deviceManagement/reports/getAppsInstallSummaryReport` — apps overview (Failed Install filters server-side to `FailedDeviceCount > 0`; Installed fetches all apps)
- `POST /beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` — per-app device install status (used by both the Failed drill-in and the Installed devices view)
- `GET /beta/deviceAppManagement/mobileApps?$filter=...&$expand=assignments` — apps with assignments. Win32-filtered server-side for Required Install; all platforms (no `$filter`, paginated) for Required Uninstall *and* the Installed sub-tab, with client-side platform filtering. Also called with `?$select=id,notes` (paginated) by the Failed Install sub-tab to build the shared Patch My PC app-id set used by both filters.
- `GET /beta/deviceAppManagement/mobileApps/{id}?$expand=assignments` — assignments for the selected app in the Installed sub-tab
- `GET /beta/deviceAppManagement/mobileApps/{id}` — full app object including the inline `rules` / `detectionRules` collection (Detection Rule Inspector modal, triggered from Installed and Failed sub-tabs)
- `DELETE /beta/deviceAppManagement/mobileApps/{id}` — permanently delete an app from the tenant (Installed sub-tab → 🗑 Delete from Intune)
- `POST /v1.0/me/sendMail` — send the MAA approver-notification email from your mailbox when a delete submission triggers HTTP 412/409 and the active customer has approvers configured
- `GET /beta/deviceManagement/operationApprovalRequests/{id}` — live status polling for an in-flight MAA delete request (30 s cadence while the modal is open; stops on approved/rejected/cancelled/expired/completed)
- `GET /beta/groups/{id}?$select=displayName,id` — group name lookup for each assignment target (Installed sub-tab)
- `GET /beta/deviceManagement/managedDevices?$select=...` — device inventory list. Hardware sub-tab uses the full property set (manufacturer/model/RAM/storage/etc); Overview sub-tab calls it with a lightweight `id,osVersion,operatingSystem,lastSyncDateTime` selection only, skipping the per-device RAM fan-out.
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

## Multi-customer (MSP) workflow

The dashboard supports a lightweight tenant switcher for consultants and MSPs juggling several Intune tenants.

**Configure your customers** in **Settings → Customers**. For each tenant you'll add:

- **Code** — required, 2–4 letters (e.g. `DB`, `XB`). The code is the *only* identifier that shows up in the dashboard's top-right tenant dropdown, so customer names stay off screenshots, recordings, and over-the-shoulder views.
- **Email** — the account UPN you sign in with for that tenant (e.g. `consultant@customer.onmicrosoft.com`).
- **Approvers** — optional comma-separated list of approver emails for that customer's MAA queue. When you submit an app delete on an MAA-enabled tenant, the dashboard immediately emails this list from your mailbox (subject: *[Intune MAA] App delete needs approval: …*) with the app name, approval code, and justification — closing the gap that Intune itself sends no notifications. Empty list = no email sent. Edit the list later by clicking the `📧 …` line inside the customer's row.

The customer list lives in `localStorage` under `intuneDashboard:customers`. **No tokens or refresh material is persisted** — MSAL continues to use `sessionStorage` exactly as before, so the only thing stored across sessions is the mapping itself.

**Switching tenants.** Once you have **two or more** customers configured, a dropdown appears next to the user name in the top-right auth bar. Pick a code → the dashboard:

- finds an MSAL account for that email in the current session and switches silently (`setActiveAccount`), or
- runs `loginPopup({ scopes, loginHint: email })` so the Microsoft sign-in popup arrives with the account pre-filled — typically one click to confirm, often no MFA prompt if the cookie is still valid.

After the switch the dashboard clears every sub-tab's cached state (`hwDevices`, `intuneApps`, `driftApps`, `assignmentsRaw`, `pmpcAppIds`, etc.) and re-renders against the new tenant, landing you on the **Overview** sub-tab as a customer-review starting point.

**Privacy/screenshot intent.** The dropdown shows only the short code — never the email. Open the dropdown to see emails; close it before screenshotting.

**With 0 or 1 customers configured**, the dashboard behaves exactly as it did before this feature existed — no dropdown appears, sign-in is a single-tenant workflow.

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

You can feed the Local tab either format:

- **PowerShell CSV** — covers HKLM 32-bit, HKLM 64-bit, and HKCU (per-user installs). Run the snippet below on a target machine.
- **Intune diagnostics REG files** — produced by the *Collect diagnostics* remote action. Specifically files `(18)` (HKLM 64-bit) and `(21)` (HKLM WOW6432Node 32-bit) from the bundle. Drop both at once for a complete HKLM picture. HKCU is not included in the Intune diagnostics export, so use the PowerShell route if you need per-user installs.

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
