# Intune Dashboard

A clean, client-side dashboard with four tabs:

1. **Local** — visualize Microsoft Intune uninstall registry exports from a CSV.
2. **Intune** — sign in with your Microsoft account and inspect your tenant live. Five sub-tabs: Installed, Failed Install, Required Install, Required Uninstall, and Hardware.
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

Sign in once with MSAL — all four sub-tabs share the same session.

**Failed Install** — the default view.
- Lists all apps with `FailedDeviceCount > 0`, sorted by failure count. `Update for*` driver/firmware apps are excluded.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Click an app to drill in to every device's install state (Application · Version · Platform · Device · User · State · Error · Last modified).
- **AI error analysis** *(optional)* — click an error code to get a diagnosis and remediation steps from Claude. Results are cached per error code in localStorage so repeat clicks are instant and free. Use the **↻ Re-analyze** button in the modal to force a fresh API call.

**Required Install** — Win32 apps assigned as *Required* to *All Devices*.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- Type to filter the list.
- `Update for*` driver/firmware apps are excluded for a cleaner audit view.

**Installed** *(default sub-tab)* — for any app, see the devices that report install status and the groups it's assigned to.
- Alphabetical list of all apps in the tenant (up to 1000), paginated 15 per page, with name/publisher search and a platform filter that defaults to *Windows*. `Update for*` driver/firmware apps are excluded.
- Click an app to drill in. The app name is a link that opens the app's blade in the Intune admin center in a new tab.
- **Assigned to** panel shows the assignment groups for the app, each tagged by intent (*Required* / *Available* / *Uninstall*). Special targets like *All Devices* and *All Users* are labeled as such; exclusion groups are marked `(exclusion)`.
- **Installed devices** table shows every device the install-status report returns: Device · User · Version · State · Platform · Last modified. The **State** dropdown defaults to whichever value starts with `installed` so you immediately see the install set; switch to *All states* to see failed, pending, etc.
- **⧉ Copy device names** copies the currently filtered list to the clipboard, newline-separated — paste straight into an Entra group, an exclusion list, or a Feature Update assignment. **⬇ Export CSV** downloads the same list (Device · User · Version · State · Platform · LastModified). Built for the use case of "give me the group of devices that have App X" — targeted upgrades and Feature Update exclusions.

**Required Uninstall** — apps assigned with intent *Uninstall* to a group.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Type to filter the list.

**Hardware** — managed-device inventory.
- KPI tiles: ten clickable buckets — OS (Windows 10, Windows 11), RAM (4GB, 8GB, 16GB, 32+ GB), and storage (64GB, 128GB, 256GB, 512+ GB). Windows 10 matches build prefix `10.0.19`; Windows 11 matches `10.0.26`. Click any tile to filter the table; click the active tile again, or hit **✕ Clear KPI** in the toolbar, to clear.
- RAM distribution donut chart.
- Filters for platform (defaults to *Windows*), RAM bucket, storage bucket, and manufacturer.
- Sortable table with device name, manufacturer, model, RAM, total/free storage, Windows version, and last check-in. Click a device name to open its Hardware blade in the Intune admin center in a new tab.
- `physicalMemoryInBytes` is fetched per device (the `managedDevices` list endpoint does not populate it), so the initial load is slower on large tenants.

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
3. Consent to the three scopes (see below)
4. The dashboard loads all apps with install failures
5. Click an app to see device-level install status

Everything runs in your browser. CSV data never leaves your machine. Intune data is fetched directly from `graph.microsoft.com` to your browser — it does not pass through any server.

## Connecting to Intune

When you click **Sign in with Microsoft**, the dashboard uses MSAL.js to open a login popup against the multi-tenant endpoint (`login.microsoftonline.com/common`). The app is pre-registered in Azure AD, so you do **not** need to create your own app registration.

**Scopes requested (delegated, read-only):**

- `DeviceManagementManagedDevices.Read.All` — read managed device data
- `DeviceManagementApps.Read.All` — read Intune app data and install reports
- `Group.Read.All` — read group names to display the groups an app is assigned to (Installed sub-tab)
- `User.Read` — read your basic profile (to show your name in the UI)

**First-time consent.** On first sign-in, you (or your tenant admin, depending on tenant policy) must consent to the scopes above. If your tenant requires admin consent for these scopes and you are not an admin, sign-in will fail with an admin-consent-required error — ask your Intune admin to grant consent for the app.

**Token storage.** Access tokens are held in browser session storage by MSAL and refreshed silently. Click **Sign out** to clear them.

**What the dashboard calls:**

- `POST /beta/deviceManagement/reports/getAppsInstallSummaryReport` — apps overview (Failed Install filters server-side to `FailedDeviceCount > 0`; Installed fetches all apps)
- `POST /beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` — per-app device install status (used by both the Failed drill-in and the Installed devices view)
- `GET /beta/deviceAppManagement/mobileApps?$filter=...&$expand=assignments` — apps with assignments (Win32-filtered server-side for Required Install; all platforms for Required Uninstall, with client-side platform filtering)
- `GET /beta/deviceAppManagement/mobileApps/{id}?$expand=assignments` — assignments for the selected app in the Installed sub-tab
- `GET /beta/groups/{id}?$select=displayName,id` — group name lookup for each assignment target (Installed sub-tab)
- `GET /beta/deviceManagement/managedDevices?$select=...` — device inventory list (for the Hardware sub-tab)
- `GET /beta/deviceManagement/managedDevices/{id}?$select=physicalMemoryInBytes` — per-device RAM fetch (the list endpoint returns 0 for this field)

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
