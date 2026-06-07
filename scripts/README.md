# Software Metering — collection script

PowerShell detection script for THE Intune Dashboard's Software Metering sub-tab. Reports per-user application last-execution data on Windows devices, agentless, via Microsoft's existing Intune Management Extension.

## What it does

1. Walks the **BAM (Background Activity Moderator)** registry per user SID for last-execution timestamps of every executable.
2. Enumerates installed apps from `HKLM\...\Uninstall` (32-bit and 64-bit) and maps BAM exe paths to their parent app via `InstallLocation` prefix match.
3. Reduces to `(app, userInitial) → mostRecentLastRun`. Computes `daysSinceUse`.
4. Adds rows for **installed-but-never-launched** apps (`daysSinceUse = -1`) — the strongest reclaim-license signal.
5. Sorts by reclaim value (never-launched first, then idle-descending), serializes to a compact pipe-separated format, gzip+base64-encodes it, and writes the result to stdout on a single line.
6. Always exits 0. If anything fails, writes `v1|error|<message>` (uncompressed, well under 2 KB) instead.
7. Appends a structured log line per checkpoint to `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneDashboard-SoftwareMetering.log` (alongside IME's own logs), auto-rotating at 1 MB. Counts only — no exe paths or usernames — so the log leaks nothing the wire payload doesn't already. Inspect on a real device for live debugging:
   ```
   Get-Content 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneDashboard-SoftwareMetering.log' -Tail 20
   ```
   Typical successful run:
   ```
   2026-05-28 03:01:14 [INFO] === Run started · schema v1 · PS 5.1.19041.4291 · OS 10.0.22631.0 ===
   2026-05-28 03:01:14 [INFO] Drive map: 2 entries
   2026-05-28 03:01:15 [INFO] Installed apps with InstallLocation: 142
   2026-05-28 03:01:16 [INFO] BAM entries: 1247 total · 612 mapped to installed apps · 3 user initial(s)
   2026-05-28 03:01:16 [INFO] Rows built: 87 launched · 55 never-launched · 4 dropped (>180 days old)
   2026-05-28 03:01:16 [INFO] Payload: 142 rows · 1816 bytes base64-gzip (cap 1950)
   2026-05-28 03:01:16 [INFO] === Run completed ===
   ```

## What it does NOT collect

- No window titles
- No document names or URLs
- No file paths
- No usernames — only the first initial of the username
- No exact timestamps in the wire format — only `daysSinceUse` (integer)
- No CPU / network / memory usage data
- Only executables matched to an installed app via ARP `InstallLocation` are reported. Stand-alone exes, OS components, dev tools run from `\bin\` folders, etc. are skipped.

The dashboard surfaces all of this further reduced (aggregates to "days since last use" on hover, never exact timestamps).

## Deploying to Intune

1. **Intune admin center** → **Devices** → **Scripts and remediations** → **Add** → **Windows**.
2. Name: `THE Intune Dashboard - Software Metering`. Description: copy from this README's "What it does / does not collect."
3. **Detection script file**: upload `software-metering-detect.ps1`.
4. **Remediation script file**: leave **empty**. This is a detection-only deployment — there's nothing to remediate.
5. **Run this script using the logged-on credentials**: **No** (run as SYSTEM).
6. **Enforce script signature check**: **No** (script is unsigned).
7. **Run script in 64-bit PowerShell**: **Yes**. Required — 32-bit PowerShell can't read the 64-bit registry hive where ARP and BAM live without WOW64 redirection workarounds.
8. **Assign** to your device group. Recommended: a pilot group (10–50 devices) first.
9. **Schedule**: **Daily**. Hourly is overkill (BAM data doesn't move that fast); run-once leaves you with stale snapshots.
10. After creation, **copy the script's GUID** from the URL (`…/intune/…/scriptPolicyId/<GUID>/…`). You'll paste this into the dashboard's Settings → Customers row.

## Configuring the dashboard

In THE Intune Dashboard:
- **Settings** → **Customers** → click your customer's row.
- Paste the script GUID into **Metering script ID**.
- Save.
- Switch to that customer, open the **Intune** tab → **Software Metering** sub-tab.

If no script ID is set, the sub-tab shows an empty-state with a link back to Settings.

## Output format

The script writes a single base64-encoded line on success. After base64-decode → gunzip you get:

```
v1|<UTC ISO timestamp>
app|publisher|ver|userInitial|daysSinceUse
Microsoft Visual Studio Code|Microsoft Corporation|1.96.2|t|0
Adobe Acrobat Reader|Adobe Inc.|24.2|t|92
Visio|Microsoft Corporation|16.0.18000|?|-1
...
```

- `userInitial` is one lowercase character (first letter of username), or `?` for never-launched / unresolvable.
- `daysSinceUse = -1` means installed but never launched (or BAM has no record).
- If the snapshot was truncated to fit the byte budget, the header line includes a `truncated=KofN` suffix: `v1|...|truncated=80of200`.

Error sentinel (not base64):

```
v1|error|<short message>
```

The dashboard detects errors by checking if the raw output starts with `v1|error|` before attempting base64-decode.

## Byte budget

Output is capped at **1950 bytes** by the script (conservative target under Intune's ~2 KB cap on `preRemediationDetectionScriptOutput`). After gzip, realistic device data fits roughly **70–100 launched-app rows + never-launched rows**. When a device exceeds the cap, the script drops rows from the tail of the reclaim-value sort — i.e., it drops actively-used rows first to preserve the idle/never-launched signal that drives the reclaim use case.

Truncation is visible via the `truncated=KofN` header flag — the dashboard surfaces a per-device "partial snapshot" footnote when present.

If your tenant's actual Intune capture limit turns out to be higher than 2 KB (some sources suggest 4–8 KB in newer Intune), bump `$MaxOutputBytes` in the script. Check by looking at the `preRemediationDetectionScriptOutput` length on real `deviceRunStates` after the script has been deployed for a day.

## Testing locally before deploying

The script reads `HKLM\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings`, which requires **SYSTEM** privileges. Running it as a regular user (or even as a local admin) returns the error sentinel:

```
v1|error|Exception calling "OpenSubKey" with "1" argument(s): "Requested registry access is not allowed."
```

To test the real path on a dev machine, run it as SYSTEM via a one-shot scheduled task **from an elevated PowerShell**:

```powershell
$script = 'C:\path\to\software-metering-detect.ps1'
$out    = "$env:TEMP\metering-test.txt"
Remove-Item $out -Force -ErrorAction SilentlyContinue
$action    = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`" > `"$out`""
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'MeteringLocalTest' -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'MeteringLocalTest'
Start-Sleep -Seconds 5
Get-Content $out
Unregister-ScheduledTask -TaskName 'MeteringLocalTest' -Confirm:$false
```

To decode the base64 output for inspection:

```powershell
$b64 = Get-Content $out -Raw
$bytes = [System.Convert]::FromBase64String($b64.Trim())
$ms = New-Object System.IO.MemoryStream(,$bytes)
$gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
$sr = New-Object System.IO.StreamReader($gz)
$sr.ReadToEnd()
```

Or, via PsExec (if Sysinternals installed): `PsExec64.exe -s -i powershell.exe -File software-metering-detect.ps1`.

## Limitations

- **Windows only.** BAM is a Windows kernel service; macOS / iOS / Android have no agentless equivalent.
- **Apps without `InstallLocation` in ARP are invisible.** Many MSI-only deployments (some Office variants, internal LOB MSIs) don't set this. Workaround: re-author the MSI with an `INSTALLDIR` property, or accept the blind spot.
- **BAM resets on Windows feature updates.** A device that just took a feature update will report most apps as never-launched until they're opened again. Mitigation: the dashboard surfaces "median snapshot age" — sudden mass shifts in never-launched counts after a Patch Tuesday week are a known false-positive pattern.
- **Roaming / multi-user devices**: BAM is per-SID; the script aggregates per-user-initial. Two users whose names start with the same letter collapse into one row (acceptable noise for the use case; preserves privacy).
- **Apps installed but launched only via custom shortcuts to a different exe** may fail the prefix match. Edge case; usually fine.

## Versioning

Schema header is `v1`. If the row format changes, bump to `v2` and the dashboard rejects older payloads with a "device running outdated metering script" badge. Deploy a new script with the new version, retire the old one.

---

# IME Required App Check-in — remediation scripts

`ime-required-app-checkin-detect.ps1` (detection) and `ime-required-app-checkin-remediate.ps1` (remediation) are vendored verbatim from Rudy Ooms / Call4Cloud's [Required-App-Checkin](https://github.com/call4cloud-code/Required-App-Checkin-public) repo. The dashboard deploys them as a single Proactive Remediation from the **Remediation** sub-tab.

## What it does

The remediation calls the Intune Management Extension's internal `IStatusService.CheckInAsync(Guid)` on the local StatusService named pipe (`net.pipe://localhost/IntuneManagementExtension/StatusService/`). This starts the **required + available apps check-in path** that normally only runs when a user clicks *Settings → Sync* in Company Portal — cutting the well-known ~60-minute wait for required Win32 apps after Autopilot or a fresh assignment. It does **not** restart the IME service and does **not** use `intunemanagementextension://syncapp` (both are weaker). The detection script returns non-compliant (exit 1) on purpose so the remediation always runs; both scripts hide their console window.

## Required Intune configuration (the dashboard's Auto-deploy sets these for you)

| Setting | Value |
| --- | --- |
| Run this script using the logged-on credentials | **Yes** |
| Run script in 64-bit PowerShell | **Yes** |
| Enforce script signature check | **No** (unless you sign the scripts yourself) |

> **Logged-on user is mandatory.** Running as SYSTEM fails with *"IME cannot resolve the user ID for the caller"* — the StatusService pipe is per-user. A user must be signed in to the device for a check-in to take effect; otherwise Intune queues it.

## On-demand use

Once deployed, the dashboard stores the remediation's script ID per customer and exposes a **⚡ Check-in** action on devices in the Hardware, Failed Install, and Cert health tabs. That fires `POST /deviceManagement/managedDevices/{id}/initiateOnDemandProactiveRemediation` with the script's `scriptPolicyId` — the same on-demand path as *Run remediation* in the Intune portal — which needs the **DeviceManagementManagedDevices.PrivilegedOperations.All** scope (requested just-in-time) and an Intune Administrator role.

This tool is unofficial and not supported by Microsoft.
