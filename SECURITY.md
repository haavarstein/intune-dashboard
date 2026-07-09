# Security

THE Intune Dashboard is a **client-side only** web app (static HTML/JS on GitHub Pages). There is no application backend. The browser talks directly to Microsoft identity endpoints, Microsoft Graph, and (optionally) Anthropic or OpenRouter for AI features.

## Data flow

| Path | What happens |
|------|----------------|
| **Local tab** | CSV / `.reg` files are parsed **in the browser**. They are not uploaded to any server. |
| **Intune tab** | After Microsoft sign-in, the browser calls `graph.microsoft.com` with a user-delegated token. Graph responses stay in page memory / session UI state. |
| **Analyze / AI error analysis** | Log snippets or error codes are sent from the browser to Anthropic or OpenRouter (depending on the key you configure). They do not pass through this project's servers. |
| **MAA notification email** | Optional: Graph `POST /me/sendMail` from **your** mailbox to approvers you configured. |

## Authentication (Microsoft)

- **Library:** MSAL.js public client application.
- **Token cache:** `sessionStorage` (not `localStorage`). Closing the browser tab ends the MSAL session; refresh tokens are not persisted across browser restarts by design.
- **Sign-in scopes:** read-oriented delegated scopes only (devices, apps, scripts, configuration, Autopilot, BitLocker key *metadata*, Entra devices/users as documented in the README).
- **Write scopes:** requested **just-in-time** the first time you use a write action (app delete, MAA approve/complete, script auto-deploy, device wipe/delete, soft-delete restore, revoke/disable user, etc.). Read-only use never needs those scopes.
- **App registration:** multi-tenant public client embedded in the page. Tenant admins may need to grant admin consent for some scopes.

## What is stored in the browser

| Storage | Contents | Secrets? |
|---------|----------|----------|
| `sessionStorage` | MSAL token cache; session AI cost counter | Auth tokens (session-scoped) |
| `localStorage` (`intuneDashboard:customers`) | MSP customer codes, emails, approver lists, script GUIDs | No tokens |
| `localStorage` (`intuneDash.claude`) | Optional Claude/OpenRouter **API key** + model choice | **Yes — treat as a secret** |
| `localStorage` | Theme preference; AI error-code response cache; last ~10 mail notification log entries | Cached AI text may include operational detail |

Clear site data for `haavarstein.github.io` (or your local origin) to wipe stored settings and keys.

## Optional AI API key

- The key is kept in **browser `localStorage`** so Analyze survives reloads.
- Anything that can run script in the page origin (XSS, a malicious browser extension with site access) could read it.
- **Recommendations:** use a **spend-capped** personal key; do not paste an unrestricted org production key; rotate if the machine or browser profile may be shared; clear Settings if you are done with AI features.

## Sensitive Graph data

- **BitLocker:** the app requests `BitlockerKey.ReadBasic.All` and uses it only for **key metadata** (e.g. whether a key is escrowed). Recovery key material is never fetched or rendered.
- **CSV exports / tables:** device names, UPNs, serials, and similar operational data appear in the UI and in user-initiated downloads. Handle screenshots and exports per your customer agreements.
- **MSP customer codes:** Settings supports short codes so screenshots can avoid full customer names. Do not put real customer identifiers into public issues, docs, or example text.

## Collection scripts (`scripts/`)

Proactive Remediation scripts (software metering, AI agent scan, IME check-in) run **on devices inside the customer tenant** under Intune. Privacy limits for metering (e.g. user initial only, no window titles) are documented in `scripts/README.md`. Deploy only with customer approval and appropriate change control.

## What not to commit

- API keys, tokens, real tenant/object IDs, real customer names/emails, or exported tenant data
- Local paths under `email/` or `.claude/` (git-ignored; may contain real data)

## Reporting a vulnerability

Please report security issues **privately**:

1. Prefer [GitHub Security Advisories](https://github.com/haavarstein/intune-dashboard/security/advisories/new) for this repository, or
2. Contact the maintainer via their GitHub profile if advisories are unavailable.

Do not open a public issue that includes exploit details, tokens, or customer data.

## Further reading

- Scope and endpoint detail: [README.md](README.md) (“Connecting to Intune”)
- Third-party script licenses: [scripts/THIRD_PARTY_NOTICES.md](scripts/THIRD_PARTY_NOTICES.md)
