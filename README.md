# THE Intune Dashboard

A clean, client-side dashboard with four tabs:

1. **Local** — visualize a Windows uninstall-registry export from a single machine. Accepts a PowerShell-generated CSV *or* the `.reg` files from an Intune **Collect diagnostics** bundle (drop one or both `.reg` files at once).
2. **Intune** — sign in with your Microsoft account and inspect your tenant live. Twenty sub-tabs: Overview, Installed, Approvals, Failed Install, Required Install, Required Uninstall, Hardware, Disk space, App versions, Autopilot, BitLocker, Management health, Assignments, Remediation, Software Metering, Vulnerabilities (P2/E5), Drift & Compliance (P2/E5), Soft-deleted (Entra recycle bin), Stale users (P1), and AI agents (P2/E5).
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

Sign in once with MSAL — all twenty sub-tabs share the same session.

**Overview** *(default sub-tab on sign-in)* — single-screen tenant health summary, framed for MSP customer-review meetings.

- Four KPI tiles: **Managed devices** (with top-3 platform breakdown), **Needing attention** (Win10 holdouts + stale-90d, deduplicated), **Apps with failures** (count + total failed-device-count subtitle), and **Drifted software** (components with >20% drift; requires Defender P2/E5).
- **Top 5 failing apps** list + **Top 5 drifted software** list side-by-side, each with a "View all →" link that jumps to the underlying Failed Install or Drift & Compliance sub-tab.
- Loads on sign-in. Three parallel lightweight calls — a `managedDevices` list with only `id,osVersion,operatingSystem,lastSyncDateTime` (no per-device RAM fan-out), the existing `getAppsInstallSummaryReport`, and the Defender drift KQL — each individually catch'd so one failure (e.g. P2/E5 not licensed) doesn't break the other tiles.
- Tenants without Defender P2/E5: the Drift tile and list show `—` with a "P2/E5 required" subtitle; everything else still renders.

**Failed Install** — apps with install failures across the fleet.
- Lists all apps with `FailedDeviceCount > 0`, sorted by failure count. `Update for*` driver/firmware apps are excluded.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Click an app to drill in to every device's install state (Application · Version · Platform · Device · User · State · Error · Last modified).
- **Grouped by device with an operational verdict (default view).** Intune's install-status report emits one row per *device + user session* — every user who signs in gets a status record — so a SYSTEM-context app can show "Installed" for one user and "Failed 0x80070643" for five others on the *same* machine, even though the install is per-device and actually succeeded. The drill-down folds those sessions into one row per device with a verdict chip: 🟢 **Installed on device** (≥1 session reports Installed — remaining failures are flagged as *stale session noise*), 🔴 **Failing** (no session reports installed), 🟡 no definitive state. Click a device row to expand the raw per-session rows. The app's `installExperience.runAsAccount` is fetched on drill-in: **user**-context apps default to the flat per-session view instead (there each row is a genuinely independent install); a hint link toggles between grouped and flat either way.
- **KPIs count devices, not session rows**: *Failing devices* (reconcilable against the assignment group's member count) · *Installed w/ stale failures* (reporting noise, not missing installs) · unique error codes and affected users counted from failed rows only. State values render as Installed/Failed badges instead of raw enum numbers.
- **Include Patch My PC** checkbox (above the app list, default unchecked) — apps created by Patch My PC Publisher are detected by their `notes` field starting with `PmpAppId` and hidden from the list by default, since they typically dominate the volume of assigned-and-failed apps in larger tenants. Tick the box to include them.
- **AI error analysis** *(optional)* — click an error code to get a diagnosis and remediation steps from Claude. Results are cached per error code in localStorage so repeat clicks are instant and free. Use the **↻ Re-analyze** button in the modal to force a fresh API call.
- **View toggle** in the picker bar — switch between *By app* (default) and *By error code* (fleet-wide error clustering). The error-clustering view fans out per-app install-status reports across every failing app in parallel and aggregates by error code, surfacing distinct codes with device count + app count + sample apps. Spots systemic issues (e.g. `0x80073cf9` across 47 devices in 5 apps = Store offline, not an app problem) vs app-specific failures.
- **🔍 Detection rule** button in the selected-app header — opens a modal showing exactly what Intune is checking for on each device (MSI ProductCode + version operator, file/folder path + version comparison, registry key + value match, or the full PowerShell detection script — base64-decoded). Read-only. Most failed-install threads on r/Intune ultimately reduce to "what does the detection rule check, and why doesn't it match?" — this answers that without leaving the dashboard.

**Required Install** — Win32 apps assigned as *Required* to *All Devices* or *All Users*.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- **Target filter** dropdown defaults to *All Devices*; switch to *All Users* to audit user-targeted required pushes, or *Either* to see both.
- Type to filter the list.
- `Update for*` driver/firmware apps are excluded for a cleaner audit view.

**Installed** — for any app, see the devices that report install status and the groups it's assigned to.
- Alphabetical list of apps that have at least one assignment (apps with no current assignment are excluded; data source is `mobileApps?$expand=assignments`, fully paginated — no 1000-app cap). Paginated 15 per page, with name/publisher search and a platform filter that defaults to *Windows*. `Update for*` driver/firmware apps are excluded.
- **Zero installs** KPI tile above the picker — counts apps assigned 30+ days ago that are installed on **zero** devices (install counts from a full paged sweep of `getAppsInstallSummaryReport`, left-joined onto the app list). These are the "urgently needed back then, used by nobody now" retire candidates. Click the tile to filter the picker to just those apps — each row then shows how long ago the app was published — and drill in to delete straight from the dashboard (🗑). The 30-day age guard keeps freshly published or staged-for-rollout apps out of the list. Green when the tenant has none, yellow otherwise.
- **Include Patch My PC** checkbox (above the app list, default unchecked) — same behavior as Failed Install: PMPC-created apps (detected via `notes` starting with `PmpAppId`) are hidden by default and surface when the box is ticked.
- Click an app to drill in. The app name is a link that opens the app's blade in the Intune admin center in a new tab.
- **Assigned to** panel shows the assignment groups for the app, each tagged by intent (*Required* / *Available* / *Uninstall*). Special targets like *All Devices* and *All Users* are labeled as such; exclusion groups are marked `(exclusion)`.
- **Installed devices** table shows every device the install-status report returns: Device · User · Version · State · Platform · Last modified. The **State** dropdown defaults to whichever value starts with `installed` so you immediately see the install set; switch to *All states* to see failed, pending, etc.
- **⧉ Copy device names** copies the currently filtered list to the clipboard, newline-separated — paste straight into an Entra group, an exclusion list, or a Feature Update assignment. **⬇ Export CSV** downloads the same list (Device · User · Version · State · Platform · LastModified). Built for the use case of "give me the group of devices that have App X" — targeted upgrades and Feature Update exclusions.
- **🔍 Detection rule** button in the selected-app header — same Detection Rule Inspector as on Failed Install. Shows the per-app detection logic that Intune evaluates on every device: MSI ProductCode + version operator, file/folder + version comparison, registry key + value match, or the full PowerShell detection script (base64-decoded). Supports Win32 LoB, Windows MSI LoB, and macOS LoB; other types show a "not applicable for this app type" message.
- **🗑 Delete from Intune** button in the selected-app header — permanently removes the app from this tenant via Graph `DELETE /deviceAppManagement/mobileApps/{id}`. Requires typing the exact app name to confirm (case-sensitive) **and** a free-text justification (sent base64-encoded as the `x-msft-approval-justification` header — recorded in the Intune audit log; required by tenants with multi-admin approval / privileged operations, ignored elsewhere). Existing installs on devices are not uninstalled, but Intune stops managing and reporting on the app. Delete is one of two write actions in the dashboard (the other is the MAA approver email below — everything else is read-only). Requires the `DeviceManagementApps.ReadWrite.All` scope (admin consent may be needed in stricter tenants). **Multi-admin approval:** if the tenant requires a second admin to approve app deletes, the request enters a pending queue (HTTP 412 with an approval code) — the dashboard shows the approval code and tells you to have an approver act on the request in *Tenant administration → Multi Admin Approval → Access requests*. Once approved there, Intune executes the delete on its own; the dashboard does not need to retry. (HTTP 409 "active Approval Request already exists" is treated the same — request is already pending; nothing to do but wait for approval.) **Auto-notify approvers:** when the customer has an approver list configured in Settings → Customers, the dashboard sends an email from your mailbox to those approvers at the moment of submission — closing the gap that Intune itself doesn't send notifications when MAA requests are created. Uses the `Mail.Send` scope and Graph `POST /v1.0/me/sendMail`. Empty approver list = no email sent. **Live status polling:** after submission, the modal polls `GET /beta/deviceManagement/operationApprovalRequests/{id}` every 30 s and updates a status row inline — *⏳ Pending → ✓ Approved by <name> (with approver note) → picker auto-refreshes* — or shows *✗ Rejected by <name>* with the reason. Uses the existing `DeviceManagementConfiguration.Read.All` scope. Polling stops on terminal state or when you close the modal.

**Approvals** — Multi-Admin Approval queue for this tenant. Every pending and recent request across apps, scripts, configuration profiles, and device actions — approve, reject, cancel, or complete inline (single or multi-select bulk) without leaving the dashboard. **Cancel** withdraws your own pending request via Graph `cancelMyRequest`. **Complete** executes an approved device action (wipe / retire / delete) by resubmitting the original operation with the `x-msft-approval-code` header — the same completion step the Intune portal's "Complete request" button performs, but available in bulk.

- **KPI tiles**: Pending (current), Approved / Rejected / Expired (last 7 days). Click a tile to filter the table.
- **Status + Type filters** plus free-text search across requestor, approver, justification, and ID.
- **Sortable table**: Requestor · Type · Status · Requested · Last updated · Justification · Actions. Pending rows expose **Approve** and **Reject** buttons; non-pending rows show a Details button.
- **Approve / Reject modal** shows the requester's justification, asks for your own justification (required, ≤ 1024 chars, recorded in the audit log), and POSTs to `operationApprovalRequests/{id}/approve` or `/reject`. Picker auto-refreshes on success.
- **No new scope** — `operationApprovalRequests` list, approve, and reject all accept the existing `DeviceManagementConfiguration.Read.All` scope.
- **Closes Intune's notification gap**: this is the queue Intune itself doesn't notify approvers about. Bookmark this tab for a single-pane-of-glass view of pending work. Paired with the auto-email-on-delete feature (Installed sub-tab → 🗑) you get the full loop: requester submits → approvers get an email + see it here → click Approve.

**Required Uninstall** — apps assigned with intent *Uninstall* to a group.
- Alphabetical list of `displayName`s. Click any row to open the app's blade in the Intune admin center in a new tab.
- **Platform filter** dropdown defaults to *Windows*; switch to *All*, *Android*, *iOS*, or *macOS* as needed.
- Type to filter the list.

**Hardware** — managed-device inventory, framed for recycle/refresh planning, Windows 11 readiness, and post-EOS Windows 10 cleanup.
- KPI tiles: fourteen clickable buckets — OS (Windows 10 [Past EOS · Oct 2025], Windows 11), **Stale 90+ days** (no check-in for 90 days+; includes never-synced devices), RAM (4GB, 8GB, 16GB, 32+ GB), storage (64GB, 128GB, 256GB, 512+ GB), and **Hygiene** (Duplicate serial — same serial across 2+ records; Missing from Entra — no matching Entra device record; No primary user — empty UPN). Windows 10 matches build prefix `10.0.19`; Windows 11 matches `10.0.26`. **Click any tile to filter the table** to just those devices; click the active tile again, or hit **✕ Clear KPI** in the toolbar, to clear.
- **⬇ Export CSV** in the toolbar downloads the currently filtered table — combine with a tile selection (e.g. *Windows 10*) to drop the result straight into an Entra group for refresh batches.
- Use cases: spot Windows 10 holdouts before end-of-support, find the low-RAM/low-storage devices that won't survive a Feature Update (or shouldn't get one), build refresh-budget shortlists, or pull a quick exclusion list of underspecced machines.
- RAM distribution donut chart for at-a-glance fleet composition.
- Filters for platform (defaults to *Windows*), RAM bucket, storage bucket, and manufacturer.
- Sortable table with device name, manufacturer, model, RAM, total/free storage, Windows version, last check-in, and a **📋 History** action. Click a device name to open its Hardware blade in the Intune admin center in a new tab; click **📋 History** to open a modal with audit events that touched that device (wipes / retires / syncs / renames / primary-user changes / RBAC). Scans `/deviceManagement/auditEvents` with a 180-day date filter and matches `resources[].resourceId` client-side — Graph's server-side `resources/any` filter on this endpoint is unreliable, so we scan up to 8 pages of 500 events. The modal shows the scan count even when zero matches, so it's clear the load worked. Uses the existing `DeviceManagementApps.Read.All` scope; Intune retains audit data up to ~1 year by default.
- `physicalMemoryInBytes` is fetched per device (the `managedDevices` list endpoint does not populate it), so the initial load is slower on large tenants.

**Autopilot** — reconciliation between Autopilot service records, Intune managed devices, and Entra device objects. Finds devices still registered in Autopilot after their Intune device was retired or reimaged, Autopilot devices with no deployment profile assigned, and duplicate Entra device objects pointing at the same Autopilot identity.

- **KPI tiles**: Autopilot devices in scope · **Orphan** (Autopilot record references a managedDeviceId that no longer exists) · **No profile** (`deploymentProfileAssignmentStatus = notAssigned`) · **Duplicate Entra** (same ZTDID across 2+ Entra device records).
- **Hide hybrid-by-design duplicates** toggle (default ON): hybrid Autopilot enrollment legitimately creates one Entra-joined + one hybrid-joined Entra record per device (`trustType: AzureAd` + `ServerAd`). Toggle off to see those too.
- Sortable table with Serial · Manufacturer · Model · Group tag · PO · Profile assignment status · Last contact · Status badge. Serial deep-links to the matching managedDevice blade when one exists, otherwise to the Autopilot devices list.
- **⬇ Export CSV** of the current filtered view.
- Uses the new `DeviceManagementServiceConfig.Read.All` scope plus the existing `DeviceManagementManagedDevices.Read.All` and `Device.Read.All` (Entra fetch is best-effort — if denied, Duplicate Entra silently shows 0 and the rest still works).

**BitLocker** — escrow-coverage audit. Windows devices reported as encrypted by Intune cross-referenced with recovery keys actually backed up in Entra. The headline number is **Encrypted, no key** — devices encrypted in Intune with zero recovery keys escrowed in Entra (your worst-case recovery scenario). What looked like a single "gap" number in earlier versions actually mixed two very different risks; the tiles now split them so the critical (red) bucket can't hide behind the policy-compliance (amber) bucket.

- **KPI tiles** (three risk tiers + a rate, all clickable except the rate):
  - **Windows devices in scope** (neutral)
  - **Encrypted + Key** (green) — fully protected
  - **Encrypted, no key** (red) — critical, real data-loss risk if the drive fails
  - **Not encrypted** (amber) — policy non-compliance
  - **Key escrow rate** — `devices with key ÷ encrypted devices`, big % with a progress ring (green ≥99 / amber <99 / red <90)
- **State filter**: All / Encrypted + Key / Encrypted, no key / Not encrypted / Encrypted (any) / Keys escrowed / No Entra link (orphaned managed devices that can't be cross-referenced).
- Sortable table with Device · User · Windows version · Model · Encryption state · Keys escrowed · Last check-in. Default sort floats gap-devices to the top.
- **⬇ Export CSV** for compliance evidence — current filtered view with state column included.
- The dashboard requests `BitlockerKey.ReadBasic.All` — the listing scope that returns key *metadata only* (id, deviceId, createdDateTime, volumeType). Recovery key material is never fetched or rendered; viewing actual keys still requires the Entra admin center.

**Vulnerabilities (P2/E5)** — software inventory from Microsoft Defender Vulnerability Management, surfaced via the Microsoft Graph Advanced Hunting API.

> ⚠️ **Licensing & role required.** This sub-tab queries Microsoft Defender Vulnerability Management data and **requires Microsoft Defender for Endpoint Plan 2 or Microsoft 365 E5** (or the standalone Defender Vulnerability Management add-on), plus the **Security Administrator** role to run the Advanced Hunting query. Without one of these licenses the tab will load empty or error out — the rest of the dashboard works regardless. The "(P2/E5)" suffix in the tab label is a reminder of this requirement.

- **KPI tile**: total count of unique software components in the tenant. Click the tile to open the Defender portal's *Vulnerability management → Inventories → Software* page in a new tab.
- Sortable table with **Software**, **OS Platform**, **Vendor**, **Weaknesses** (distinct CVE count for that software), and **Exposed Devices** (distinct devices with **at least one open CVE for this software** — sourced from `DeviceTvmSoftwareVulnerabilities`, not the inventory table, so Defender's own components no longer show the entire fleet as exposed). Default sort is Weaknesses descending so the riskiest software floats to the top.
- Click any **Software** name to open the Defender portal's inventory page in a new tab for further investigation. (Defender doesn't expose a stable software ID via KQL, so the link goes to the inventory list rather than deep-linking to the specific row.)
- Type to filter across software name, vendor, and platform.
- Lazy-loaded: the query runs the first time you open the tab, then caches for the session. Use **↻ Refresh** to force a re-fetch.

**Drift & Compliance (P2/E5)** — fleet-wide software version drift, surfaced from Microsoft Defender Vulnerability Management via the Advanced Hunting API. Highlights software where devices are running mixed versions of the same product (e.g. .NET Desktop Runtime 8 alongside 9, Snagit across major versions).

> ⚠️ **Licensing & role required.** This sub-tab queries `DeviceTvmSoftwareInventory` and **requires Microsoft Defender for Endpoint Plan 2 or Microsoft 365 E5**, plus the **Security Administrator** role to run the Advanced Hunting query (same constraint as Vulnerabilities). Devices must be Defender-onboarded to appear in the data.

- **KPI tiles**: count of software with > 10% drift, fleet drift average, total devices affected, and the single top-drifted software component.
- Sortable table with **Software**, **Vendor**, **Dominant Version**, **Drift %**, **Drifted Devices**, and **Versions Detected**. Drift % > 20% is highlighted. Default sort is Drift % descending.
- Click any **Software** name to open the Defender portal's inventory page for that software in a new tab — same deep-link pattern as the Vulnerabilities sub-tab, falling back to the inventory list when Defender doesn't expose a stable software ID.
- Type to filter across software name and vendor. **⬇ Export CSV** downloads the current filtered view.
- Lazy-loaded: one KQL call against Defender on first open, cached for the session. Use **↻ Refresh** to force a re-fetch.
- Because data is grouped by *software name + vendor*, this catches the cross-Intune-app product-family drift that the install-status reports can't see — apps installed outside Intune, image-baked software, and major-version splits are all visible.

**Management health** — Intune management capability, derived from the MDM certificate lifecycle. A device whose management certificate has expired can look perfectly healthy in the Intune portal — compliant, recently synced, online — while Win32 apps, remediation scripts and every other IME-driven workload have silently stopped (IME can't authenticate; ClientCertCheck reports zero MDM certificates; registry shows `RenewStatus = 3` / `0x80180018`). Graph exposes the tell-tale property (`managementCertificateExpirationDate`); the portal just never translates it into operational impact. This tab does — the expired-cert + recent-sync signature matched 6/6 devices (3 broken, 3 healthy controls) in the tenant investigation that motivated it.

- **Health states**: 🔴 **Management failure likely** (cert expired) · 🟠 **At risk** (expires ≤ 30 days) · 🟡 **Stale** (no check-in ≥ 14 days) · 🟢 **Healthy**. Deliberately non-absolute wording — the dashboard infers from Graph data and observed tenant patterns; it doesn't inspect the client.
- **Risk column**: **High** = expired cert *and* synced within 7 days — the device still checks in and looks fine while management is likely dead, the most dangerous state because admins assume it's healthy. **Medium** = expired-but-silent or expiring soon; **Low** = stale.
- **Health Assessment panel** — click any health badge or the per-row **🔍 Investigate** action. Structured as *Assessment* (state + risk + verdict) · *Confidence* (High/Medium/Low with the derivation: `managementCertificateExpirationDate`, sync recency, observed tenant patterns) · *Evidence* · *Likely symptoms* (pending Win32 installs, scripts not executing, hourly IME auth retries) · *Recommended validation* (ClientCertCheck.log, IntuneManagementExtension.log, `LocalMachine\My`, `RenewStatus`/`RenewErrorCode`) · *Recommended remediation* (trigger cert renewal via sync, re-enroll if renewal fails, verify enrollment) — plus a **⚡ Force check-in / sync now** action so remediation starts from the panel.
- **KPI tiles**: Windows devices in scope · Management failure likely · At risk · Stale · Management health rate gauge. Tiles click-filter the table.
- Sortable table with Device · User · Windows · Days remaining (negative for expired) · Cert expires · Days since sync · Risk · Health. Default sort is Days remaining ascending — devices closest to silent drop-off float to the top.
- Device names deep-link to the device's Intune blade.
- **🗑 Delete selected** — checkbox column with a filtered-view select-all lets you delete one or many devices from Intune in one action (e.g. clean out broken devices you've re-enrolled). Confirmation lists the device names and warns about impact; deletion removes the Intune record and retires the device on its next check-in. MAA-aware: one justification prompt covers the whole batch, and devices whose deletes are queued for approval (412/409) are reported separately from deleted/failed. Requests `DeviceManagementManagedDevices.ReadWrite.All` just-in-time.
- **⬇ Export CSV** (includes Health + Risk) for a snapshot of the at-risk fleet.
- Viewing uses the existing `DeviceManagementManagedDevices.Read.All` scope — no new consent until you delete.

**Soft-deleted** — Entra ID device recycle bin (preview). Lists soft-deleted Entra device objects with a per-row **↻ Restore** action so admins can recover accidentally deleted devices within the 30-day window without dropping to Microsoft Graph PowerShell. The recycle bin preserves BitLocker recovery keys, LAPS passwords, device identity, and key material — restoring the object brings all of that back and the Intune managed-device record auto-relinks within a few minutes.

- Sortable table with **Device name**, **OS**, **Trust type**, **Object ID** (first 8 chars; hover for full GUID), **Deleted at**, **Days remaining** (warn-cell when ≤ 5), **Enabled at delete**, and **Action**. Default sort is *deleted-at descending* so the most recent deletions float to the top.
- The **Object ID** column is the disambiguator when the same hostname has multiple stale objects in the recycle bin — common after re-enrollment loops or stale-device cleanup sweeps. Each entry is a distinct directory object with its own GUID.
- 404 on restore is treated as success (already restored / aged out — the row is removed and a success banner shown).
- LIST piggybacks on the existing `Device.Read.All` scope (no extra consent to view the bin).
- RESTORE requires `Directory.AccessAsUser.All` — requested **just-in-time** on first click so list-only viewers aren't pestered at sign-in. Only Cloud Device Administrator, Intune Administrator, or Global Administrator can complete the restore (Entra role requirement, enforced by Graph).
- **Hybrid-joined devices are hard-deleted on removal** and never appear here — Microsoft only soft-deletes Entra-joined and Entra-registered devices in the current preview.
- Lazy-loaded on first open; **↻ Refresh** forces a re-fetch.

**Stale users (P1)** — license-reclaim / identity-hygiene view for customer reviews. Surfaces Entra **member** accounts that are inactive or never signed in, so an MSP can say *"you have N accounts idle 90+ days holding ~M unused licenses."* Read-only by default; account changes deep-link to Entra, with optional in-app Revoke / Disable actions gated just-in-time.

> ⚠️ **Licensing required.** This sub-tab reads the `signInActivity` property from `/v1.0/users`, which is **only populated for tenants licensed for Entra ID P1 or P2**. Without P1/P2 the dashboard renders a "P1/P2 required" empty state and the rest of the tab can't compute idle days. The "(P1)" suffix in the tab label is the reminder.

- **In scope**: `userType == 'Member'` and `accountEnabled == true`. Guests are excluded (`revokeSignInSessions` doesn't work on guests anyway), and already-disabled accounts are excluded (re-disabling is a no-op).
- **Last activity** is the most recent of `lastSignInDateTime`, `lastNonInteractiveSignInDateTime`, and `lastSuccessfulSignInDateTime` — so accounts active non-interactively (mail clients, sync agents) aren't false-flagged. All three null = never signed in.
- **KPI tiles** (clickable to filter): Members in scope · **Idle 90+ days** (amber, threshold tracks the dropdown) · **Never signed in** (yellow) · **Licensed & stale** (red — in-scope users with ≥1 `assignedLicenses` that are also idle ≥ threshold or never-signed-in; this is the reclaim headline).
- **Threshold dropdown** (30 / 60 / 90 / 180 days, default 90) re-filters client-side — no re-fetch. Plus an **Include never-signed-in** toggle (default on).
- Sortable table: Display name (deep-links to the user's blade in the Entra admin center in a new tab) · UPN · Last activity · Days idle · Sign-in badge (*Never* / *Active record*) · Licensed (count) · Status. Default sort is **never-first, then days-idle descending** so the highest-confidence reclaim candidates float to the top.
- **⬇ Export CSV** of the current filtered view (`DisplayName, UPN, LastActivity, DaysIdle, NeverSignedIn, LicenseCount, AccountEnabled`).
- **Optional in-app actions** (per-row, gated behind a confirm modal that states the effect):
  - **↻ Revoke sessions** — `POST /v1.0/users/{id}/revokeSignInSessions`. Invalidates refresh tokens; forces re-auth. Live access tokens remain valid for up to ~1 hour unless the resource enforces CAE. Requests `User.RevokeSessions.All` **just-in-time** on first use.
  - **⊘ Disable account** — `PATCH /v1.0/users/{id}` with `{accountEnabled:false}`. Blocks new sign-ins; live access tokens still persist ~1h without CAE. Requires typing `DISABLE` in the confirm box, mirroring the app-delete name-confirm guard. Requests `User.EnableDisableAccount.All` **just-in-time** on first use.
  - Row updates inline on success/fail; list-only viewers are never prompted for the write scopes.
- **Read scopes**: `User.Read.All` + `AuditLog.Read.All` (the latter gates `signInActivity` on the Graph side). Added in the same release as this sub-tab; existing users will see a one-time re-consent prompt.
- Lazy-loaded on first open; **↻ Refresh** forces a re-fetch.

**AI agents (P2/E5)** — shadow-AI visibility. Lists locally installed AI agents discovered across managed devices by Defender for Endpoint **agent discovery (preview)**. Coverage is catalog-based — CLI agents (Claude Code, Codex, Gemini CLI, GitHub Copilot CLI, OpenCode), desktop apps (ChatGPT, Claude, Codex, Ollama, Poe), agentic IDEs (Cursor, Windsurf, Antigravity), VS Code extensions (Claude Code, Cline, Copilot, Roo Code), and Claw-based agents; see [Microsoft's supported-agent list](https://learn.microsoft.com/en-us/defender-endpoint/local-agent-discovery-overview). Agents not in the catalog are invisible to discovery. Detection logic adapted from [SlimKQL / Detections.AI](https://github.com/SlimKQL/Detections.AI/blob/main/KQL/agent-365--local-ai-agent-installation-detection.kql) — the original alerts on a 24-hour window; the dashboard shows the full inventory and surfaces recent installs as a warn tile instead.

Because the preview's hunting schema is in flux, the tab **cascades through four data sources** and a banner states which one answered: **`AgentsInfo`** (the replacement table — tried first) → **`AIAgentsInfo`** (SlimKQL's original, retired **July 1, 2026**) → the **exposure graph** (`ExposureGraphEdges`, `endpointAiAgent` → *runs on* → device — Microsoft's documented home for endpoint agent discovery; carries agent + device only, so vendor/user/timestamp columns show "—" from that source) → the **fleet scan** below. A 400 from a source means the table doesn't exist in the tenant and the next is tried. Zero rows everywhere renders a per-source outcome line plus discovery prerequisites instead of a silent empty table.

**Fleet scan (works today, no Defender preview needed).** Microsoft's agent discovery is a staged preview (currently gated behind Defender's Beta platform/engine update channel), so the tab ships its own collector: **`scripts/ai-agent-detect.ps1`**, a Proactive Remediation in the Software Metering mold — deployed in one click from the tab's empty state (**⚡ Deploy AI Agent Scan…**, same auto-deploy wizard, MAA-aware, `DeviceManagementScripts.ReadWrite.All` just-in-time). Running daily as SYSTEM it sweeps every user profile through seven channels — WinGet packages, machine-wide ARP, desktop-app folders, npm globals, VS Code extensions, agent config dirs, running processes — against a catalog of known agents (Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, Claude/ChatGPT/Ollama/LM Studio/Poe desktop, Cursor, Windsurf, Cline, Roo Code, Continue, Aider, OpenCode, OpenClaw, Hermes Agent), dedupes per `(agent, user)`, and reports `agent|vendor|ver|user|via|daysAgo` as a gzip+base64 snapshot through the detection-output channel. The dashboard reads `/deviceRunStates`, self-links the script by display name (no GUID paste), and uses it only when the Defender sources are empty — once Microsoft enables discovery by default, the native source takes over automatically. Unlike metering, the **username is transmitted** (security inventory — *who* runs the agent is the point); no prompts, file contents, or usage data are collected. See `scripts/README.md`.

> ⚠️ **Licensing / rollout required.** Advanced hunting needs **Defender for Endpoint P2 or M365 E5** (same `ThreatHunting.Read.All` scope as the Vulnerabilities tab — no new consent), *and* the `AIAgentsInfo` table only exists once the Agent 365 preview reaches the tenant. Tenants without it get a "table not available" notice instead of a raw KQL 400; the tab lights up automatically once the preview lands. The signed-in **user** also needs a Defender security role — **Security Administrator**, or **Security Reader** for read-only. Defender XDR evaluates the user's own `SecurityData.Read` / `TvmData.Read` permissions on top of the app scope, so even a Global Administrator without a security role gets a 403 (the dashboard explains this in-app on all three advanced-hunting tabs).

- **KPI tiles**: **Agent installs** (total detections; click to show all) · **Unique agents** (distinct agent names; click to group the table by agent) · **Devices with agents** · **New (7 days)** (amber, click-to-filter — the recently-installed slice) · **Fleet footprint** (SVG gauge — share of Defender-onboarded devices seen in the last 7 days with ≥1 local AI agent; amber on purpose, it's a watch metric, not a success rate; fed by a second, individually-caught `DeviceInfo` query so its failure never breaks the tab).
- **Two table views** (dropdown): **Installations** (Agent name with a *New* badge · Vendor · Device · OS · User · Detected, default sort newest first) and **By agent name** (Agent · Vendor · Installs · Devices · Last detected, default sort most-installed first). Both sortable; search filters across agent, vendor, device, and user.
- **⬇ Export CSV** of the current filtered view, shaped to whichever view is active.
- Lazy-loaded on first open; **↻ Refresh** forces a re-fetch.

**Disk space** — Win32 app requirement-rule pre-flight. The Intune Win32 `Disk space required (MB)` requirement rule silently marks devices as **Requirements not met** or **Not Applicable** when free space is below the rule — no obvious error in the Intune console, just a missing install. This tab lists Windows devices below a chosen free-space threshold so you can find the silent victims before they call helpdesk. Background context for *why* this matters in 2025–2026: Microsoft incident **IT1168328** (the Intune Store / WinGet log bloat bug) silently filled `%windir%\Temp\WinGet\defaultState`, and Windows 11 24H2 upgrades have pushed disk pressure up across the fleet.

- **KPI tiles**: Windows devices in scope · **< 1 GB free** (red, emergency / Windows breaking) · **< 5 GB free** (amber, at-risk / common helpdesk pain) · **< 20 GB free** (yellow, watch / proactive monitoring band) · **Lowest free** (worst offender in the fleet, with device name). The three coloured tiles are click-to-filter; click again to clear.
- **Threshold dropdown** with seven MB-based bands matching Intune's own `Disk space required (MB)` field: `< 250 MB` (small Win32 rule fails) · `< 500 MB` (medium Win32 rule fails) · `< 1 GB` (emergency) · `< 2 GB` (most installers fail) · `< 5 GB` (helpdesk pain) · `< 10 GB` (alert default) · `< 20 GB` (warning band). MB-based on purpose — matches the unit admins type into the Win32 requirement rule, so a 2 GB filter shows exactly the devices that would fail a 2 GB requirement.
- Sortable table with Device · User · Windows · Model · Free · Total · Free % · Last check-in. Default sort is **Free ascending** so the worst-off devices float to the top. Free-space cell is colour-coded by band (red < 1 GB, amber < 5 GB, yellow < 20 GB, green ≥ 20 GB).
- Common error codes when an install does attempt and fails on disk: `0x80070070` (not enough space on disk) and `0x87D30067` (extraction failed, often disk-related). The IME log at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` is where to confirm root cause.
- **⬇ Export CSV** for the current filtered view.
- Uses the existing `DeviceManagementManagedDevices.Read.All` scope — **no new consent**. Self-contained Graph call (`beta/deviceManagement/managedDevices` with a slim `$select` filtered to `operatingSystem eq 'Windows'`) so the tab loads fast even if Hardware hasn't been opened yet.

**App versions** — version-sprawl hygiene in your **Intune app catalog** (`deviceAppManagement/mobileApps`) — the app *packages* you've created/uploaded, **assigned or not**. Often you accumulate many versions of the same product (the classic "eleven Notepad++ packages" mess, typically from PatchMyPC publishing or manual re-uploads); this tab groups the catalog by normalized product name, counts how many packages exist per app, and flags the ones safe to retire. The actionable output is a clean delete list — and you can delete right here.

- **KPI tiles**: **Multi-version apps** (apps held in >1 package, click to filter) · **Worst offender** (most packages, click to open it) · **Surplus packages** (packages older than the app's newest version, click to filter) · **Unassigned packages** (packages targeting no group — orphans, safest to delete, click to filter) · **Single-version rate** — a gauge ring showing the share of catalog apps held in exactly one package (green ≥ 85%, yellow ≥ 60%, red below).
- **Only apps with duplicates** toggle (on by default) hides single-package apps so the version sprawl is all you see; the footer reports how many were hidden. Untoggle for the full catalog.
- Sortable app table (App · Publisher · Packages · Newest version · Assigned · Unassigned · Platform); package count is colour-coded (≥ 10 red, ≥ 5 amber). Click any app to drill into its **per-package breakdown** — each package's version, assignment status/intent (Required / Available / Uninstall, or **Unassigned**), and created date, with the newest flagged and older ones marked as cleanup targets.
- **Delete inline**: each package row has **Open ↗** (deep-link to the app in the Intune admin center) and **🗑** (delete from Intune). The 🗑 reuses the same typed-confirm Delete-from-Intune flow as the Installed sub-tab — multi-admin-approval aware, requests the `DeviceManagementApps.ReadWrite.All` write scope just-in-time. After a successful delete the tab re-computes its counts.
- Grouping collapses architecture markers (x64/x86/user/machine) and trailing version tails so packages of the same product group together regardless of naming convention; version is read from `displayVersion` / `productVersion` per app type.
- **⬇ Export CSV** of the current view (app summary, or the per-package breakdown when drilled in). Lazy-loaded on first open; **↻ Refresh** forces a re-fetch.
- Read path uses the existing `DeviceManagementApps.Read.All` scope — **no new consent** to view. Reuses the same paginated `mobileApps?$expand=assignments` call as the Installed sub-tab.

**Assignments** — group-centric reverse lookup *plus* tenant-wide hygiene. Pick an Entra group → see every policy targeting it, across seven types: apps, configuration profiles (legacy), settings catalog, compliance policies, PowerShell scripts, proactive remediation scripts, and Windows Update profiles (feature, quality, and driver).

**Hygiene panel** (top of the tab) surfaces operational cruft computed from the same cache:
- **Unassigned items** — policies / apps / scripts with no assignments at all (candidates for cleanup).
- **Empty-group assignments** — silent no-ops where an assignment targets a group with zero members. Computed by parallel `GET /v1.0/groups/{id}/members/$count` for every unique group ID referenced across the seven categories.
- **Orphaned filters** — assignment filters that exist but are referenced by no assignment.
- **Filters in use** — assignment filters referenced by at least one assignment (click for the usage list).
Click any tile to drill into the full list with deep-links into the Intune admin center. Closes the gap behind community tools like IntuneAssignmentChecker and SMSAgentSoftware's Power BI reports.

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
- **⚡ IME Required App Check-in — run on a device of choice (on-demand).** A card at the top of the tab lets you **search for a Windows device and force a required-app check-in on it**. It runs Rudy Ooms / Call4Cloud's [Required-App-Checkin](https://github.com/call4cloud-code/Required-App-Checkin-public) remediation, which calls the Intune Management Extension's internal `IStatusService.CheckInAsync` to kick the **required + available apps** path — cutting the well-known ~60-minute delay for required Win32 apps after Autopilot or a fresh assignment. This is a **device-targeted tool, not a scheduled or group-assigned rollout.** The same **⚡ Check-in** action also appears on every device row in the **Hardware** and **Failed Install** tabs, and inside the **Management health** Health Assessment panel (these problems overlap — a stuck cert or a failed required install is exactly when you want to force a sync).
- **Run activity.** Because on-demand runs don't roll up into Intune's Endpoint analytics Remediations report (it only aggregates *assigned* deployments — an on-demand-only remediation shows there as "Not deployed" with zero stats), the card reads the per-device results directly and shows *"⚙ Run on N devices on-demand · last <date> · <k> with remediation errors"* so you can see real usage. (Note: by design the remediation always shows **"With issues"** per device — the detection script exits 1 every time so the remediation always runs.)
- **How the on-demand run works.** The action fires `POST …/managedDevices/{id}/initiateOnDemandProactiveRemediation` — the same *Run remediation* on-demand path as the Intune portal. Intune has no API to push an arbitrary script to a single device ad-hoc; on-demand always references an existing remediation by ID. So the first time you run a check-in in a tenant, the dashboard **auto-creates the remediation once, unassigned** (no group, no schedule) from the `scripts/` files, base64-encoded, configured **Run as logged-on user = Yes**, **64-bit PowerShell = Yes**, **signature check = No** (it *must* run as the signed-in user — as SYSTEM it fails with *"IME cannot resolve the user ID for the caller"*). That script ID is saved per customer (Settings → Customers → *IME check-in script*) and reused for every later run; the remediation shows up in the list above like any other (with no assignments). Creation is idempotent (reuses a same-named script) and Multi-Admin Approval is handled. Requires `DeviceManagementScripts.ReadWrite.All` (first create) and `DeviceManagementManagedDevices.PrivilegedOperations.All` (the on-demand run) — both requested just-in-time — plus an Intune Administrator role.
- **Verify a run.** The remediation runs as the logged-on user and logs to that user's profile — on the device, signed in as that user, check `%LOCALAPPDATA%\IMERequiredAppCheckinRemediation\Logs` (each run writes `IMERequiredAppCheckin_<timestamp>.log` recording the `IStatusService.CheckInAsync` result). The dashboard's IME card shows this path for easy copy/paste. (`%ProgramData%\...\IntuneManagementExtension\Logs` is **not** used — it's SYSTEM-owned and unwritable by the user the script runs as.)
- **On-demand needs the device reachable *now*.** Per Microsoft, on-demand remediations are **not queued** — the target must be online and able to reach Intune and **Windows Push (WNS)** at the moment you run it, with the Intune Management Extension installed and a signed-in user (the check-in runs as that user). If the device isn't reachable the call returns **404 ResourceNotFound** — force a sync on the device and retry. Only one Run-remediation can be in flight per device at a time. Note: on-demand results don't roll up into Intune's Endpoint analytics report (it stays "Not deployed / 0") — they appear per-device, which is what the card's run-activity line reads.

**Software Metering** — agentless per-user application usage on Intune-managed Windows devices. Closes the "is this license actually being used?" question without deploying a metering agent — the data is collected by a Proactive Remediation detection script that reads Windows' built-in BAM (Background Activity Moderator) registry on a daily schedule and emits a gzip-compressed snapshot via the detection script's stdout channel. The dashboard fans out across `/deviceHealthScripts/{id}/deviceRunStates`, decodes per-device, aggregates fleet-wide.

> **Per-customer config required.** Two paths: **⚡ Auto-deploy** (one click from the sub-tab's empty state — the dashboard creates the Proactive Remediation in this tenant and assigns it to your chosen group or All Devices, then auto-fills the script ID in Settings; requires consent for the `DeviceManagementScripts.ReadWrite.All` write scope on first use; idempotent — detects a name collision and offers to reuse the existing script instead of duplicating), or **manual** (upload `scripts/software-metering-detect.ps1` to Intune yourself, then paste the script's GUID into **Settings → Customers → Metering script ID** for the customer). See `scripts/README.md` for the manual deploy recipe and the portal metadata block. If the locally stored script ID goes missing or stale (every redeploy mints a new ID; browser storage can be cleared), the tab self-heals: it looks the script up by its default display name and re-links automatically before falling back to the deploy wizard.

- **KPI tiles**: Devices reporting (with median snapshot-age subtitle) · Apps tracked across the fleet · **Likely unused** (install × device pairs idle 90+ days or never launched; clickable filter) · **Reclaim candidates** (apps installed on ≥10 devices where ≥50% of installs are idle 90+ days or never launched; clickable filter).
- Sortable main table: **App** · **Publisher** · **Installs** · **Active 30d** · **Idle 90d+** · **Never launched** · **Last fleet use**. Default sort: Idle 90d+ desc. Reclaim-candidate rows have their Idle 90d+ cell highlighted.
- Click any row to drill into a per-device list: **Device** · **User** (first initial only) · **Version** · **Days since use** · **Last reported**. Default sort: Days since use desc (dead first). Device name deep-links to its Intune blade. **⬇ Export CSV** of the drilldown gives you the exact list of devices to reclaim a seat from.
- Lazy-loaded; one call per session against `/deviceRunStates`. Use **↻ Refresh** to invalidate the cache.
- **Privacy posture**: the collection script reports only `(installed app, user-initial, days-since-use)` triples. No window titles, document names, URLs, file paths, or full usernames are collected or transmitted. Exact timestamps are reduced to integer day-counts before they leave the device. The dashboard mirrors this — drilldown shows "47d" not a wall-clock timestamp.
- **Snapshot-only, no history**: this is a current-state view. Trend lines would require backend storage, which is out of scope for this client-side dashboard.

### Analyze tab (log files)
- **Drop-zone upload** for one or more Intune log files (IME, AgentExecutor, MSI verbose, etc.)
- **Auto-trim** preprocessor — greps for error/failure/return-value lines (including negative and HRESULT-style decimal error codes) and keeps ±15 lines of context around each match. Deduplicates overlapping windows. Cuts input tokens ~80% with no quality loss for triage. Toggle off to send the full log.
- **Size guard** — the prompt is capped under the model's 200k-token context. If a log is still too big after trimming, it is re-trimmed with tighter context (±3 lines), and as a last resort the oldest entries are dropped — the newest activity (usually the failure under investigation) is always kept. The status line tells you when this happens.
- **Haiku 4.5 by default** — cheapest, fastest, separate rate-limit bucket. Switch to Sonnet 5 in Settings for tougher logs.
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

**Scopes requested at sign-in (delegated, all read-only):**

- `DeviceManagementManagedDevices.Read.All` — read managed device data
- `DeviceManagementApps.Read.All` — read Intune app data and install reports
- `BitlockerKey.ReadBasic.All` — list BitLocker recovery-key metadata for the BitLocker sub-tab (returns id / deviceId / volumeType only — key material is never fetched)
- `Device.Read.All` — read Entra device objects, used by the Hardware tab's hygiene tiles to flag Intune devices with no matching Entra record
- `Group.Read.All` — read group names to display the groups an app is assigned to (Installed sub-tab)
- `User.Read` — read your basic profile (to show your name in the UI)
- `User.Read.All` — read directory users (Stale users sub-tab); pairs with `AuditLog.Read.All` below
- `AuditLog.Read.All` — gates the `signInActivity` property on `/v1.0/users` (Stale users sub-tab); without it, Graph silently omits the property
- `ThreatHunting.Read.All` — run Defender Advanced Hunting KQL queries (Vulnerabilities, Drift & Compliance, and AI agents sub-tabs; requires Defender for Endpoint P2 or M365 E5 to return data). Defender additionally checks the signed-in **user's** security permissions (`SecurityData.Read` / `TvmData.Read`) — the user needs a **Security Administrator** or **Security Reader** role; Global Administrator alone returns 403
- `DeviceManagementScripts.Read.All` — read Intune device health scripts (Remediation sub-tab) and PowerShell scripts (Assignments sub-tab)
- `DeviceManagementConfiguration.Read.All` — read configuration profiles, settings catalog policies, compliance policies, and Windows Update profiles (Assignments sub-tab)
- `DeviceManagementServiceConfig.Read.All` — read Autopilot device identities (Autopilot sub-tab)

**Just-in-time write scopes (not requested at sign-in):** each is requested via a consent popup the first time you use the matching write action in a session, so read-only viewers never carry write permissions.

- `DeviceManagementApps.ReadWrite.All` — deleting apps from Intune (Installed sub-tab → 🗑 Delete from Intune) and approving/rejecting Multi-Admin-Approval requests (Approvals sub-tab)
- `Mail.Send` — send the MAA approver notification email from your own mailbox at the moment a delete is submitted; never used for anything else
- `DeviceManagementScripts.ReadWrite.All` — the Software Metering ⚡ Auto-deploy, the AI agents tab's ⚡ Deploy AI Agent Scan, and the Remediation tab's ⚡ IME Required App Check-in deploy (each creates a Proactive Remediation in the tenant + assigns it)
- `Directory.AccessAsUser.All` — the Soft-deleted sub-tab's ↻ Restore button. Requires admin consent and an Entra role of Cloud Device Administrator, Intune Administrator, or Global Administrator on the signed-in account; the LIST call uses the existing `Device.Read.All` scope.
- `User.RevokeSessions.All` — the Stale users sub-tab's ↻ Revoke sessions button.
- `User.EnableDisableAccount.All` — the Stale users sub-tab's ⊘ Disable account button. Confirm modal requires typing `DISABLE` before the button enables.
- `DeviceManagementManagedDevices.PrivilegedOperations.All` — the per-device **⚡ Check-in** action (Hardware / Failed Install rows + the Management health assessment panel), which fires `initiateOnDemandProactiveRemediation` to force an IME required-app sync; requires an Intune Administrator role.
- `DeviceManagementManagedDevices.ReadWrite.All` — the Management health tab's **🗑 Delete selected** bulk device delete

Everything requested at sign-in is read-only; all seven write scopes are just-in-time. Stricter tenants may require admin consent for the write scopes; if you can't consent yourself, an Intune admin needs to grant it before 🗑 Delete from Intune, the approver-notification email, ⚡ Auto-deploy, ↻ Restore (Soft-deleted sub-tab), and ↻ Revoke / ⊘ Disable (Stale users sub-tab) will work.

**First-time consent.** On first sign-in, you (or your tenant admin, depending on tenant policy) must consent to the scopes above. If your tenant requires admin consent for these scopes and you are not an admin, sign-in will fail with an admin-consent-required error — ask your Intune admin to grant consent for the app. Existing users will see a one-time re-consent prompt whenever a new scope is added (most recently `User.Read.All` and `AuditLog.Read.All` for the Stale users sub-tab).

**Token storage.** Access tokens are held in browser session storage by MSAL and refreshed silently. Click **Sign out** to clear them.

**What the dashboard calls:**

- `POST /beta/deviceManagement/reports/getAppsInstallSummaryReport` — apps overview (Failed Install filters server-side to `FailedDeviceCount > 0`; Installed fetches all apps)
- `POST /beta/deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` — per-app device install status (used by both the Failed drill-in and the Installed devices view)
- `GET /beta/deviceAppManagement/mobileApps?$filter=...&$expand=assignments` — apps with assignments. Win32-filtered server-side for Required Install; all platforms (no `$filter`, paginated) for Required Uninstall *and* the Installed sub-tab, with client-side platform filtering. Also called with `?$select=id,notes` (paginated) by the Failed Install sub-tab to build the shared Patch My PC app-id set used by both filters. The **App versions** sub-tab reuses the full paginated `?$expand=assignments` form to group the catalog by product and count version/package sprawl (assigned *and* unassigned).
- `GET /beta/deviceAppManagement/mobileApps/{id}?$expand=assignments` — assignments for the selected app in the Installed sub-tab
- `GET /beta/deviceAppManagement/mobileApps/{id}` — full app object including the inline `rules` / `detectionRules` collection (Detection Rule Inspector modal, triggered from Installed and Failed sub-tabs)
- `DELETE /beta/deviceAppManagement/mobileApps/{id}` — permanently delete an app from the tenant (Installed sub-tab → 🗑 Delete from Intune, and App versions sub-tab → per-package 🗑)
- `DELETE /beta/deviceManagement/managedDevices/{id}` — the Management health tab's **🗑 Delete selected** bulk action; removes the Intune device record (the device retires on its next check-in). Multi-Admin-Approval aware — one justification is prompted for the whole batch and 412/409 responses are reported as queued for approval (needs the JIT `DeviceManagementManagedDevices.ReadWrite.All` scope)
- `POST /v1.0/me/sendMail` — send the MAA approver-notification email from your mailbox when a delete submission triggers HTTP 412/409 and the active customer has approvers configured
- `GET /beta/deviceManagement/operationApprovalRequests/{id}` — live status polling for an in-flight MAA delete request (30 s cadence while the modal is open; stops on approved/rejected/cancelled/expired/completed)
- `GET /beta/deviceManagement/operationApprovalRequests` — full MAA queue (Approvals sub-tab; paginated)
- `POST /beta/deviceManagement/operationApprovalRequests/{id}/approve` and `…/reject` — inline Approve/Reject actions from the Approvals sub-tab (no new scope; `DeviceManagementConfiguration.Read.All` covers both)
- `POST /beta/deviceManagement/operationApprovalRequests/cancelMyRequest` — Cancel your own pending request from the Approvals sub-tab (request ID in the body; only the original requestor can cancel)
- `POST /beta/deviceManagement/managedDevices/{id}/wipe`, `…/retire`, `DELETE …/managedDevices/{id}` with the `x-msft-approval-code: <request id>` header — Complete an approved MAA device action by resubmitting the original operation (per Microsoft's "Use Multi Admin Approval with the Microsoft Graph API" doc)
- `GET /v1.0/informationProtection/bitlocker/recoveryKeys` — recovery key metadata (no key material) for the BitLocker sub-tab's escrow-gap audit; joined to `managedDevices.azureADDeviceId`
- `GET /v1.0/devices?$select=deviceId` — Entra device IDs joined to `managedDevices.azureADDeviceId` for the Hardware tab's "Missing from Entra" hygiene tile
- `GET /beta/deviceManagement/windowsAutopilotDeviceIdentities` — Autopilot device records for the Autopilot sub-tab; joined to `managedDevices` by `managedDeviceId` for orphan detection and to Entra `/devices` by ZTDID (extracted from `physicalIds`) for duplicate-Entra detection
- `GET /v1.0/deviceManagement/auditEvents?$filter=activityDateTime ge <180d>` — per-device action history for the Hardware tab's 📋 History modal; scans up to 8 pages of 500 and matches `resources[].resourceId` client-side (server-side `resources/any` filter on this endpoint is unreliable)
- `GET /beta/deviceManagement/assignmentFilters` — assignment filters list for the Assignments → Hygiene panel (orphaned vs in-use detection)
- `GET /v1.0/groups/{id}/members/$count` (with `ConsistencyLevel: eventual`) — per-group member counts for the Assignments → Hygiene panel's empty-group detector (parallelized for every unique group ID referenced in assignments)
- `GET /beta/groups/{id}?$select=displayName,id` — group name lookup for each assignment target (Installed sub-tab)
- `GET /beta/deviceManagement/managedDevices?$select=...` — device inventory list. Hardware sub-tab uses the full property set (manufacturer/model/RAM/storage/etc); Overview sub-tab calls it with a lightweight `id,osVersion,operatingSystem,lastSyncDateTime` selection only, skipping the per-device RAM fan-out.
- `GET /beta/deviceManagement/managedDevices/{id}?$select=physicalMemoryInBytes` — per-device RAM fetch (the list endpoint returns 0 for this field)
- `POST /v1.0/security/runHuntingQuery` — Defender Advanced Hunting KQL query against `DeviceTvmSoftwareInventory` and `DeviceTvmSoftwareVulnerabilities` (Vulnerabilities sub-tab), against `DeviceTvmSoftwareInventory` grouped by `SoftwareName, SoftwareVendor, SoftwareVersion` (Drift & Compliance sub-tab), and — for the AI agents sub-tab — a source cascade of `AgentsInfo` → `AIAgentsInfo` (`Platform == "LocalAgents"`, parsing `RawAgentInfo`) → `ExposureGraphEdges` (`endpointAiAgent` nodes), plus a `DeviceInfo` device count for the footprint gauge
- `GET /beta/deviceManagement/deviceHealthScripts?$expand=assignments` — proactive remediation scripts with their assignments (Remediation sub-tab, reused by Assignments sub-tab)
- `GET /beta/deviceManagement/deviceHealthScripts/{id}/deviceRunStates?$expand=managedDevice` — per-device output from the software metering detection script (Software Metering sub-tab) and the AI Agent Scan detection script (AI agents sub-tab fleet-scan source); decoded client-side from base64+gzip
- `GET /beta/deviceManagement/deviceHealthScripts?$filter=displayName eq '…'` — pre-create idempotency check for the Software Metering ⚡ Auto-deploy button (offers to reuse an existing script with the same name rather than duplicating)
- `POST /beta/deviceManagement/deviceHealthScripts` and `…/{id}/assign` — create + assign the metering Proactive Remediation from the dashboard's ⚡ Auto-deploy button (Software Metering empty state); the script content is fetched same-origin from `scripts/software-metering-detect.ps1`, base64-encoded, and posted with `runAsAccount=system`, `runAs32Bit=false`, `enforceSignatureCheck=false`, plus a daily-schedule assignment to the chosen group or All Devices
- `POST /beta/deviceManagement/deviceHealthScripts` — auto-create (once, **unassigned**) the **IME Required App Check-in** remediation the first time a check-in runs in a tenant; both scripts are fetched same-origin from `scripts/ime-required-app-checkin-{detect,remediate}.ps1`, base64-encoded into `detectionScriptContent` + `remediationScriptContent`, and posted with `runAsAccount=user`, `runAs32Bit=false`, `enforceSignatureCheck=false`. No `…/assign` call is made — it's a device-targeted tool, not a scheduled rollout
- `PATCH /beta/deviceManagement/deviceHealthScripts/{id}` — self-update: a content fingerprint of the local `.ps1` files is stored with the script ID, and when it drifts (you edited a script) the next check-in re-uploads the content to the existing remediation in place, so edits self-deploy without delete/recreate
- `GET /beta/deviceManagement/managedDevices?$filter=startswith(deviceName,'…')` — device type-ahead for the Remediation-tab IME check-in picker (Windows devices filtered client-side)
- `POST /beta/deviceManagement/managedDevices/{id}/initiateOnDemandProactiveRemediation` — the **⚡ Check-in** action (Remediation-tab picker + per-row buttons on Hardware / Failed Install + the Management health assessment panel); posts `{ scriptPolicyId }` of the IME remediation to force an on-demand required-app sync on the chosen device (needs the JIT `DeviceManagementManagedDevices.PrivilegedOperations.All` scope)
- `GET /v1.0/groups?$search="displayName:…"` — Entra group type-ahead search (Assignments sub-tab; sent with `ConsistencyLevel: eventual` header)
- `GET /beta/deviceManagement/deviceConfigurations?$expand=assignments` — configuration profiles (legacy) with their assignments (Assignments sub-tab)
- `GET /beta/deviceManagement/deviceCompliancePolicies?$expand=assignments` — compliance policies with their assignments (Assignments sub-tab)
- `GET /beta/deviceManagement/configurationPolicies?$expand=assignments` — settings catalog policies (Assignments sub-tab)
- `GET /beta/deviceManagement/deviceManagementScripts?$expand=assignments` — PowerShell scripts (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsFeatureUpdateProfiles?$expand=assignments` — Windows Feature Update profiles (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsQualityUpdateProfiles?$expand=assignments` — Windows Quality Update profiles (Assignments sub-tab)
- `GET /beta/deviceManagement/windowsDriverUpdateProfiles?$expand=assignments` — Windows Driver Update profiles (Assignments sub-tab; requires Autopatch licensing in some tenants — silently skipped if 403)
- `GET /beta/directory/deletedItems/microsoft.graph.device?$select=...&$top=100` — soft-deleted Entra device objects with their `deletedDateTime`, `trustType`, `accountEnabled`, etc. (Soft-deleted sub-tab); paginated via `@odata.nextLink`
- `POST /beta/directory/deletedItems/{id}/restore` — restore a soft-deleted Entra device object (Soft-deleted sub-tab → ↻ Restore); uses a token minted just-in-time for `Directory.AccessAsUser.All` rather than the static `SCOPES` array
- `GET /v1.0/users?$select=id,displayName,userPrincipalName,accountEnabled,userType,signInActivity,assignedLicenses&$top=999` — directory users for the Stale users sub-tab; fully paginated via `@odata.nextLink`. `signInActivity` requires Entra ID P1/P2 and the `AuditLog.Read.All` scope
- `POST /v1.0/users/{id}/revokeSignInSessions` — invalidate refresh tokens for a stale user (Stale users sub-tab → ↻ Revoke sessions); uses a token minted just-in-time for `User.RevokeSessions.All`
- `PATCH /v1.0/users/{id}` with `{accountEnabled:false}` — disable a stale account (Stale users sub-tab → ⊘ Disable account); uses a token minted just-in-time for `User.EnableDisableAccount.All`

These are the same endpoints the Intune admin center uses for its "Apps install status" and "Device install status" views.

## Multi-customer (MSP) workflow

The dashboard supports a lightweight tenant switcher for consultants and MSPs juggling several Intune tenants.

**Configure your customers** in **Settings → Customers**. For each tenant you'll add:

- **Code** — required, 2–4 letters (e.g. `DB`, `XB`). The code is the *only* identifier that shows up in the dashboard's top-right tenant dropdown, so customer names stay off screenshots, recordings, and over-the-shoulder views.
- **Email** — the account UPN you sign in with for that tenant (e.g. `consultant@customer.onmicrosoft.com`).
- **Approvers** — optional comma-separated list of approver emails for that customer's MAA queue. When you submit an app delete on an MAA-enabled tenant, the dashboard immediately emails this list from your mailbox (subject: *[Intune MAA] App delete needs approval: …*) with the app name, approval code, justification, and a **Review this request in Intune** button that deep-links straight to the Multi Admin Approval blade — closing the gap that Intune itself sends no notifications. Empty list = no email sent. Edit the list later by clicking the `📧 …` line inside the customer's row.
- **✉ Send test** — next to any configured approver list. Sends a clearly-marked test email through the exact same Graph path (`/me/sendMail`, `Mail.Send` scope) so you can verify notifications work for that customer without submitting a real delete. Failures surface an actionable message inline — the most common cause is that **the signed-in account has no Exchange Online mailbox** (the email sends *from your mailbox*, so unlicensed admin accounts can't send; Graph returns `MailboxNotEnabledForRESTAPI`). Other mapped causes: the `Mail.Send` consent popup being blocked, and tenants requiring admin consent.
- **Notification log** — the last 10 approver-email attempts (test + real) are kept in `localStorage` and shown under the customer list with timestamp, customer, recipients, and result, so "the email never arrived" reports are diagnosable after the fact.
- **Matching caveat** — the approver list is picked by matching the signed-in account's UPN to a customer's login email. If no customer matches (e.g. guest/GDAP identity, or a typo in the login email), the submission panel now says so explicitly instead of claiming no approvers are configured; duplicate login emails across customers trigger a warning in Settings since only the first match wins.
- **Software metering script ID** — optional GUID of the Proactive Remediation script uploaded for software metering (see `scripts/README.md`). Required to enable the Software Metering sub-tab for that customer; if empty, that sub-tab shows a setup empty-state. Edit later by clicking the `🔧 …` line inside the customer's row.
- **IME check-in script ID** — optional GUID of the IME Required App Check-in remediation (see `scripts/README.md`). **Auto-filled on the first check-in** you run in that tenant (the dashboard creates the remediation unassigned and stores the ID, plus a content fingerprint so script edits self-deploy); you normally never touch this. Clear or edit it by clicking the `⚡ …` line inside the customer's row — handy if you delete the remediation in Intune and want the next check-in to recreate it.

The customer list lives in `localStorage` under `intuneDashboard:customers`. **No tokens or refresh material is persisted** — MSAL continues to use `sessionStorage` exactly as before, so the only thing stored across sessions is the mapping itself.

**Switching tenants.** Once you have **two or more** customers configured, a dropdown appears next to the user name in the top-right auth bar. Pick a code → the dashboard:

- finds an MSAL account for that email in the current session and switches silently (`setActiveAccount`), or
- runs `loginPopup({ scopes, loginHint: email })` so the Microsoft sign-in popup arrives with the account pre-filled — typically one click to confirm, often no MFA prompt if the cookie is still valid.

After the switch the dashboard clears every sub-tab's cached state (`hwDevices`, `intuneApps`, `driftApps`, `assignmentsRaw`, `pmpcAppIds`, etc.) and re-renders against the new tenant, landing you on the **Overview** sub-tab as a customer-review starting point.

**Privacy/screenshot intent.** The dropdown shows only the short code — never the email. Open the dropdown to see emails; close it before screenshotting.

**With 0 or 1 customers configured**, the dashboard behaves exactly as it did before this feature existed — no dropdown appears, sign-in is a single-tenant workflow.

## AI error analysis (optional)

If you add a Claude API key under the **Settings** tab, error-code cells in the device table become clickable. Clicking sends the app + device + error context to the Claude API and shows a structured diagnosis (what the error means, likely cause, remediation steps) in a modal.

**Anthropic or OpenRouter.** The key field accepts either an Anthropic key (`sk-ant-…`) or an [OpenRouter](https://openrouter.ai/) key (`sk-or-…`) — the provider is auto-detected from the prefix, no separate setting. With an OpenRouter key the same Claude models are used (`anthropic/claude-haiku-4.5` etc.) and billed through your OpenRouter account, which is handy if you already fund multiple AI tools from one balance there.

Analyses are cached per `errorCode + model` in `localStorage`. Re-clicking the same error code renders instantly from cache with a **Cached** badge — no API call, no tokens spent. Click **↻ Re-analyze** in the modal header to force a fresh response (useful if you change models or want to retry).

**Models available:**

| Model | Price (per MTok) | Approx. cost per click | Good for |
| --- | --- | --- | --- |
| Haiku 4.5 *(default)* | $1 / $5 | ~$0.0025 | Most triage; cheapest, separate rate-limit bucket |
| Sonnet 5 | $3 / $15 *($2 / $10 intro through Aug 2026)* | ~$0.0075 | Escalate for longer logs or harder root-cause work |
| Opus 4.8 | $5 / $25 | ~$0.0125 | Reserve for stuck cases |
| Fable 5 | $10 / $50 | ~$0.025 | Anthropic's most capable model — last resort for the gnarliest logs |

**A note on model choice.** Haiku 4.5 is the default for everything — it's the cheapest current-generation model and uses a separate rate-limit bucket from Sonnet/Opus, so heavy Sonnet usage elsewhere won't throttle your dashboard. For most error codes and routine log triage, Haiku is enough. Escalate to **Sonnet 5** when Haiku misses something — its real strength is correlating timestamps across long IME logs and isolating root cause from noise (and it's on $2/$10 introductory pricing through August 2026). Reserve **Opus 4.8** for cases where Sonnet gives up; the Opus 4.7+ tokenizer uses ~30% more tokens for the same input, so the effective cost gap is wider than headline pricing suggests. **Fable 5** sits above Opus at 2× the price with higher latency — a last resort for logs nothing else can untangle. (Previously saved Sonnet 4.6 / Opus 4.7 selections keep working — both models are still served — but the picker now offers the current generation.) The biggest cost lever regardless of model is **auto-trim** (the toggle on the Analyze tab) — it greps for error/return-value lines plus surrounding context and typically cuts input tokens 80%+ with no quality loss.

**Where the API key lives.** The key is stored in your browser's `localStorage` and sent only to `api.anthropic.com` (Anthropic keys) or `openrouter.ai` (OpenRouter keys). Either way **the key is readable by anyone who can open DevTools on this page**. This is fine for a personal tool you run yourself. **Do not paste an API key into a shared or public deployment.** If you want to share the tool with a team, route the call through a backend (Cloudflare Worker, Vercel function, etc.) that holds the key server-side.

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

## Acknowledgements

Some one-click remediations are **vendored from other people's public repos** —
the original authors keep all credit. Full ledger and licenses:
[`scripts/THIRD_PARTY_NOTICES.md`](scripts/THIRD_PARTY_NOTICES.md).

- **IME Required App Check-in** (Remediation tab) is [Rudy Ooms](https://call4cloud.nl)' ([@Mister_MDM](https://twitter.com/Mister_MDM)) [Required-App-Checkin](https://github.com/call4cloud-code/Required-App-Checkin-public), MIT-licensed, vendored verbatim.

## License

MIT — see [LICENSE](LICENSE). Vendored third-party scripts retain their own licenses; see [`scripts/THIRD_PARTY_NOTICES.md`](scripts/THIRD_PARTY_NOTICES.md).
