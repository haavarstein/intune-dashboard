# Intune Dashboard

A clean, client-side dashboard for two things:

1. **Local view** — visualize Microsoft Intune uninstall registry exports from a CSV.
2. **Intune view** — sign in with your Microsoft account and inspect Intune app-install failures live, with optional AI-powered error-code analysis.

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
- **Live sign-in** to your Microsoft tenant via MSAL (popup)
- **Failed-apps overview** — lists Windows apps with `FailedDeviceCount > 0`, sorted by failure count, with Platform column
- **Per-app drill-in** — click an app to see every device's install state (Application · Version · Platform · Device · User · State · Error · Last modified)
- **AI error analysis** *(optional)* — click an error code to get a diagnosis and remediation steps from Claude

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
4. The dashboard loads all Windows apps with install failures
5. Click an app to see device-level install status

Everything runs in your browser. CSV data never leaves your machine. Intune data is fetched directly from `graph.microsoft.com` to your browser — it does not pass through any server.

## Connecting to Intune

When you click **Sign in with Microsoft**, the dashboard uses MSAL.js to open a login popup against the multi-tenant endpoint (`login.microsoftonline.com/common`). The app is pre-registered in Azure AD, so you do **not** need to create your own app registration.

**Scopes requested (delegated, read-only):**

- `DeviceManagementManagedDevices.Read.All` — read managed device data
- `DeviceManagementApps.Read.All` — read Intune app data and install reports
- `User.Read` — read your basic profile (to show your name in the UI)

**First-time consent.** On first sign-in, you (or your tenant admin, depending on tenant policy) must consent to the scopes above. If your tenant requires admin consent for these scopes and you are not an admin, sign-in will fail with an admin-consent-required error — ask your Intune admin to grant consent for the app.

**Token storage.** Access tokens are held in browser session storage by MSAL and refreshed silently. Click **Sign out** to clear them.

**What the dashboard calls:**

- `POST /beta/deviceManagement/reports/getAppsInstallSummaryReport` — the failed-apps overview
- `POST /beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` — per-app device install status

These are the same endpoints the Intune admin center uses for its "Apps install status" and "Device install status" views.

## AI error analysis (optional)

If you add a Claude API key under the **Settings** tab, error-code cells in the device table become clickable. Clicking sends the app + device + error context to the Claude API and shows a structured diagnosis (what the error means, likely cause, remediation steps) in a modal.

**Models available:**

| Model | Price (per MTok) | Approx. cost per click | Good for |
| --- | --- | --- | --- |
| Haiku 4.5 *(default)* | $1 / $5 | ~$0.0025 | Fast lookups, recommended |
| Sonnet 4.6 | $3 / $15 | ~$0.0075 | Deeper remediation guidance |
| Opus 4.7 | $5 / $25 | ~$0.0125 | Usually overkill for error codes |

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
