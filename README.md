# THE Intune Dashboard

Client-side Microsoft Intune / Entra ops dashboard for MSPs and admins. Runs in the browser only — no backend. Sign in with Microsoft Graph (MSAL); optional Claude/OpenRouter for log and error analysis.

🔗 **Live:** [haavarstein.github.io/intune-dashboard](https://haavarstein.github.io/intune-dashboard/)  
🔒 **Security:** [SECURITY.md](SECURITY.md)  
📘 **Full feature reference:** [docs/FEATURES.md](docs/FEATURES.md) (detailed tabs, endpoints, edge cases)

---

## What you get

| Tab | Purpose |
|-----|---------|
| **Local** | Visualize uninstall registry from CSV or Intune Collect diagnostics `.reg` files |
| **Intune** | Live tenant: 20 sub-tabs (apps, hardware, MAA, Autopilot, BitLocker, Defender views, metering, …) |
| **Analyze** | Drop IME / AgentExecutor / MSI logs → AI triage (optional API key) |
| **Settings** | MSP customer list, approvers, metering script IDs, Claude/OpenRouter key |

**Intune sub-tabs (20):** Overview · Installed · Approvals · Failed Install · Required Install · Required Uninstall · Software Metering · Remediation · Hardware · Disk Space · App Versions · Autopilot · BitLocker · Management Health · Assignments · Vulnerabilities (P2/E5) · Drift & Compliance (P2/E5) · Soft-Deleted · Stale Users (P1) · AI Agents (P2/E5)

Highlights that fill portal gaps: failed-install session-noise verdicts, MAA queue + email notifications, management-certificate health, BitLocker key-escrow gaps, app version sprawl cleanup, software metering via Proactive Remediation, Autopilot orphan reconciliation.

---

## Quick start

### Local tab
1. Export uninstall data (PowerShell snippet in [docs/FEATURES.md](docs/FEATURES.md#exporting-the-registry-for-the-local-tab), or Intune **Collect diagnostics** `.reg` files).
2. Open the [live dashboard](https://haavarstein.github.io/intune-dashboard/) → **Local**.
3. Drop `.csv` or `.reg` files. Search, sort, copy uninstall strings.

### Intune tab
1. **Sign in with Microsoft** (popup → multi-tenant `login.microsoftonline.com/common`).
2. Consent to the read scopes (listed below). Write scopes are requested only when you use a write action.
3. **Overview** loads first; open any other sub-tab as needed.

### Analyze tab
1. Settings → paste an Anthropic (`sk-ant-…`) or OpenRouter (`sk-or-v1-…`) key (stored in browser `localStorage`).
2. Drop log files → **Analyze with Claude**. Prefer Haiku for cost/speed.

### Local development
Do **not** open `index.html` as `file://` (MSAL redirect fails). From the repo root:

```bash
python -m http.server 8080
# open http://localhost:8080/
```

---

## Connecting to Intune

Pre-registered multi-tenant public client (MSAL.js). Tokens stay in **`sessionStorage`**. Customer list / API key use **`localStorage`** (no refresh tokens persisted across browser restarts).

### Read scopes (sign-in)

| Scope | Used for |
|-------|----------|
| `DeviceManagementManagedDevices.Read.All` | Devices, hardware, disk, cert health, … |
| `DeviceManagementApps.Read.All` | Apps, install reports, audit history |
| `DeviceManagementScripts.Read.All` | Remediations, PowerShell scripts |
| `DeviceManagementConfiguration.Read.All` | Policies, MAA queue list, update profiles |
| `DeviceManagementServiceConfig.Read.All` | Autopilot |
| `Group.Read.All` | Assignment group names |
| `User.Read` | Signed-in display name |
| `User.Read.All` + `AuditLog.Read.All` | Stale users (`signInActivity`) |
| `ThreatHunting.Read.All` | Defender KQL (Vulnerabilities, Drift, AI agents) — needs P2/E5 + security role |
| `BitlockerKey.ReadBasic.All` | BitLocker key **metadata only** (no recovery material) |
| `Device.Read.All` | Entra devices (hygiene / Autopilot duplicates / soft-delete list) |

### Write scopes (just-in-time)

Requested only on first use of the matching action:

| Scope | Action |
|-------|--------|
| `DeviceManagementApps.ReadWrite.All` | Delete apps; MAA approve/reject/complete (apps) |
| `Mail.Send` | MAA notification emails from your mailbox |
| `DeviceManagementScripts.ReadWrite.All` | Auto-deploy metering / AI scan / IME check-in scripts |
| `Directory.AccessAsUser.All` | Restore soft-deleted Entra devices |
| `User.RevokeSessions.All` / `User.EnableDisableAccount.All` | Stale users actions |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | On-demand IME check-in |
| `DeviceManagementManagedDevices.ReadWrite.All` | Device delete/wipe; complete device MAA |
| `DeviceManagementRBAC.ReadWrite.All` / `DeviceManagementConfiguration.ReadWrite.All` | Complete certain MAA create/update requests |

Stricter tenants may need admin consent for write scopes. Full endpoint list and edge cases: [docs/FEATURES.md](docs/FEATURES.md#connecting-to-intune).

---

## Multi-customer (MSP)

In **Settings → Customers**, add short codes (e.g. `ACME`), login email, optional approvers and metering script GUIDs. With **2+** customers, a code-only dropdown appears in the auth bar (screenshot-safe). Switching uses MSAL `loginHint` / cached accounts; no tokens stored for the list. Details: [docs/FEATURES.md](docs/FEATURES.md#multi-customer-msp-workflow).

---

## Optional AI

- **Anthropic or OpenRouter** key in Settings; models selectable (Haiku default).
- Used for error-code analysis and log triage; key never sent to Microsoft Graph.
- Prefer a **spend-capped** key. See [SECURITY.md](SECURITY.md).

---

## Scripts

Proactive Remediation collectors (software metering, AI agent scan, IME required-app check-in) live under [`scripts/`](scripts/) with deploy steps in [`scripts/README.md`](scripts/README.md). Third-party notices: [`scripts/THIRD_PARTY_NOTICES.md`](scripts/THIRD_PARTY_NOTICES.md).

---

## Tech

| Piece | Location |
|-------|----------|
| UI + tab logic | `index.html` |
| Styles | `css/dashboard.css` |
| MSAL config + read scopes | `js/msal-config.js` |
| Graph helpers | `js/graph.js` |
| Collectors | `scripts/*.ps1` |

No build step. MSAL + PapaParse from CDN. Static hosting (GitHub Pages).

---

## Contributing / docs map

| Doc | Content |
|-----|---------|
| [README.md](README.md) | Overview, quick start, scopes (this file) |
| [docs/FEATURES.md](docs/FEATURES.md) | Full tab-by-tab reference, Graph calls, registry export snippet |
| [SECURITY.md](SECURITY.md) | Data flow, storage, reporting vulnerabilities |
| [scripts/README.md](scripts/README.md) | Deploy metering / AI scan / IME check-in |
| [tasks/todo.md](tasks/todo.md) | Active backlog |
| [CLAUDE.md](CLAUDE.md) | Agent coding rules for this repo |

---

## Acknowledgements

Vendored remediations and licenses: [`scripts/THIRD_PARTY_NOTICES.md`](scripts/THIRD_PARTY_NOTICES.md).  
IME Required App Check-in: [Rudy Ooms / Call4Cloud](https://github.com/call4cloud-code/Required-App-Checkin-public) (MIT).

## License

MIT — see [LICENSE](LICENSE).
