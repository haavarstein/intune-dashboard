# Intune Dashboard - Software Metering (detection script)
#
# Collects last-execution timestamps from BAM (Background Activity Moderator),
# maps them to installed apps via Add/Remove Programs InstallLocation, and emits
# a gzip+base64-encoded snapshot on stdout. The Intune Dashboard reads this
# snapshot per device via /deviceHealthScripts/{id}/deviceRunStates.
#
# Deploy as a Proactive Remediation DETECTION script only (no remediation).
# Run as SYSTEM, 64-bit, on a Daily schedule. Always exits 0.
#
# Payload format:
#   v1|<ISO timestamp>
#   app|publisher|ver|userInitial|daysSinceUse
#   <rows...>
# On error:
#   v1|error|<message>   (plain text, not base64)

$ErrorActionPreference = 'Stop'
$MaxOutputBytes        = 1950   # ~2 KB cap on preRemediationDetectionScriptOutput
$MaxAgeDays            = 180    # BAM beyond this is unreliable
$NeverLaunchedSentinel = -1

# --- Drive map: \Device\HarddiskVolumeN -> C: ---------------------------------
Add-Type -Namespace IntuneDashboard -Name Kernel32 -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto, SetLastError = true)]
public static extern int QueryDosDevice(string lpDeviceName, System.Text.StringBuilder lpTargetPath, int ucchMax);
'@

function Get-DriveMap {
    $map = @{}
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Name.Length -eq 1 })) {
        $sb = New-Object System.Text.StringBuilder 1024
        $letter = "$($drive.Name):"
        $rc = [IntuneDashboard.Kernel32]::QueryDosDevice($letter, $sb, $sb.Capacity)
        if ($rc -ne 0) {
            $devicePath = $sb.ToString()
            if ($devicePath) { $map[$devicePath] = $letter }
        }
    }
    return $map
}

function Convert-BamPath {
    param([string]$BamPath, [hashtable]$DriveMap)
    foreach ($dev in $DriveMap.Keys) {
        if ($BamPath.StartsWith($dev, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $DriveMap[$dev] + $BamPath.Substring($dev.Length)
        }
    }
    return $null
}

# --- SID resolution -----------------------------------------------------------
function Resolve-SidToUser {
    param([string]$Sid)
    try {
        $obj  = [System.Security.Principal.SecurityIdentifier]::new($Sid)
        $acct = $obj.Translate([System.Security.Principal.NTAccount]).Value
        return $acct.Split('\')[-1]
    } catch {}
    try {
        $pp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Sid" -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
        return Split-Path $pp -Leaf
    } catch {}
    return $null
}

# --- BAM walk -----------------------------------------------------------------
function Get-BamEntries {
    $roots = @(
        'SYSTEM\CurrentControlSet\Services\bam\State\UserSettings',
        'SYSTEM\CurrentControlSet\Services\bam\UserSettings'
    )
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Default')
    try {
        foreach ($root in $roots) {
            $rk = $base.OpenSubKey($root)
            if (-not $rk) { continue }
            try {
                foreach ($sidName in $rk.GetSubKeyNames()) {
                    if ($sidName -notmatch '^S-1-5-21-') { continue }   # user SIDs only
                    $user = Resolve-SidToUser $sidName
                    if (-not $user) { continue }
                    $initial = $user.Substring(0, 1).ToLower()
                    $uk = $rk.OpenSubKey($sidName)
                    if (-not $uk) { continue }
                    try {
                        foreach ($valueName in $uk.GetValueNames()) {
                            if ($uk.GetValueKind($valueName) -ne [Microsoft.Win32.RegistryValueKind]::Binary) { continue }
                            $data = $uk.GetValue($valueName)
                            if ($data -isnot [byte[]] -or $data.Length -lt 8) { continue }
                            $ft = [System.BitConverter]::ToInt64($data, 0)
                            if ($ft -le 0) { continue }
                            try {
                                $last = [System.DateTime]::FromFileTimeUtc($ft)
                            } catch { continue }
                            [PSCustomObject]@{
                                ExePath  = $valueName
                                LastRun  = $last
                                Initial  = $initial
                            }
                        }
                    } finally { $uk.Close() }
                }
            } finally { $rk.Close() }
            return
        }
    } finally { $base.Close() }
}

# --- Installed apps from ARP --------------------------------------------------
function Get-InstalledApps {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = New-Object System.Collections.Generic.List[object]
    foreach ($entry in (Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue)) {
        if (-not $entry.DisplayName) { continue }
        if ($entry.SystemComponent -eq 1) { continue }
        if (-not $entry.InstallLocation) { continue }
        $loc = $entry.InstallLocation.Trim().Trim('"').TrimEnd('\')
        if (-not $loc -or $loc -match '^[A-Z]:\\?$') { continue }   # skip root-of-drive
        $pub = ''
        if ($entry.Publisher) { $pub = $entry.Publisher.Trim() }
        $ver = ''
        if ($entry.DisplayVersion) { $ver = "$($entry.DisplayVersion)".Trim() }
        $apps.Add([PSCustomObject]@{
            DisplayName     = $entry.DisplayName.Trim()
            Publisher       = $pub
            Version         = $ver
            InstallLocation = $loc
        })
    }
    return $apps.ToArray()
}

function Find-AppForExe {
    param([string]$ExePathWin, [object[]]$AppsByLengthDesc)
    foreach ($app in $AppsByLengthDesc) {
        $loc = $app.InstallLocation
        if ($ExePathWin.Equals($loc, [System.StringComparison]::OrdinalIgnoreCase)) { return $app }
        if ($ExePathWin.StartsWith($loc + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $app }
    }
    return $null
}

# --- Serialization ------------------------------------------------------------
function Format-Field {
    param([string]$Value)
    if (-not $Value) { return '' }
    return ($Value -replace '[\|\r\n\t]', ' ').Trim()
}

function Compress-Payload {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $ms = New-Object System.IO.MemoryStream
    try {
        $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionLevel]::Optimal)
        try { $gz.Write($bytes, 0, $bytes.Length) } finally { $gz.Close() }
        return [System.Convert]::ToBase64String($ms.ToArray())
    } finally { $ms.Dispose() }
}

function Build-Payload {
    param([object[]]$Rows, [int]$OriginalCount = -1)
    $sb = New-Object System.Text.StringBuilder
    $header = "v1|$([System.DateTime]::UtcNow.ToString('o'))"
    if ($OriginalCount -ge 0 -and $OriginalCount -ne $Rows.Count) {
        $header += "|truncated=$($Rows.Count)of$OriginalCount"
    }
    [void]$sb.AppendLine($header)
    [void]$sb.AppendLine('app|publisher|ver|userInitial|daysSinceUse')
    foreach ($r in $Rows) { [void]$sb.AppendLine($r.Line) }
    return $sb.ToString().TrimEnd("`r`n".ToCharArray())
}

# --- Main ---------------------------------------------------------------------
try {
    $driveMap = Get-DriveMap
    if ($driveMap.Count -eq 0) { throw 'no drive map' }

    $installedApps = Get-InstalledApps
    if (-not $installedApps -or $installedApps.Count -eq 0) {
        Write-Output (Compress-Payload (Build-Payload @()))
        exit 0
    }
    $appsByLen = $installedApps | Sort-Object { $_.InstallLocation.Length } -Descending

    # Aggregate BAM hits per (DisplayName, userInitial)
    $now   = [System.DateTime]::UtcNow
    $usage = @{}
    foreach ($entry in Get-BamEntries) {
        $win = Convert-BamPath -BamPath $entry.ExePath -DriveMap $driveMap
        if (-not $win) { continue }
        $app = Find-AppForExe -ExePathWin $win -AppsByLengthDesc $appsByLen
        if (-not $app) { continue }
        $key = "$($app.DisplayName)|$($entry.Initial)"
        if (-not $usage.ContainsKey($key) -or $usage[$key].LastRun -lt $entry.LastRun) {
            $usage[$key] = [PSCustomObject]@{
                App     = $app
                Initial = $entry.Initial
                LastRun = $entry.LastRun
            }
        }
    }

    # Build rows: launched + installed-but-never-launched
    $launchedNames = New-Object System.Collections.Generic.HashSet[string]
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($v in $usage.Values) {
        [void]$launchedNames.Add($v.App.DisplayName)
        $days = [int]($now - $v.LastRun).TotalDays
        if ($days -lt 0) { $days = 0 }
        if ($days -gt $MaxAgeDays) { continue }   # unreliable
        $line = '{0}|{1}|{2}|{3}|{4}' -f (Format-Field $v.App.DisplayName), (Format-Field $v.App.Publisher), (Format-Field $v.App.Version), $v.Initial, $days
        # ReclaimValue: higher = more valuable to keep under budget pressure (idle/never-launched
        # are the reclaim signal). Active rows are dropped first when bytes get tight.
        $rows.Add([PSCustomObject]@{ Line = $line; Days = $days; ReclaimValue = $days })
    }
    foreach ($app in $installedApps) {
        if ($launchedNames.Contains($app.DisplayName)) { continue }
        $line = '{0}|{1}|{2}|{3}|{4}' -f (Format-Field $app.DisplayName), (Format-Field $app.Publisher), (Format-Field $app.Version), '?', $NeverLaunchedSentinel
        # Never-launched outranks any launched row — these are the strongest reclaim signal.
        $rows.Add([PSCustomObject]@{ Line = $line; Days = $NeverLaunchedSentinel; ReclaimValue = 999 })
    }

    # Sort by reclaim value DESCENDING: keep never-launched + idle, drop active under pressure.
    $sorted = @($rows | Sort-Object @{Expression='ReclaimValue';Descending=$true}, Line)
    $originalCount = $sorted.Count

    # Compress and enforce byte budget; drop from the TAIL (= lowest reclaim value = active).
    $encoded = Compress-Payload (Build-Payload $sorted $originalCount)
    if ($encoded.Length -gt $MaxOutputBytes) {
        $list = New-Object System.Collections.Generic.List[object]
        $list.AddRange($sorted)
        while ($encoded.Length -gt $MaxOutputBytes -and $list.Count -gt 25) {
            $list.RemoveRange($list.Count - 25, 25)
            $encoded = Compress-Payload (Build-Payload $list $originalCount)
        }
        while ($encoded.Length -gt $MaxOutputBytes -and $list.Count -gt 0) {
            $list.RemoveAt($list.Count - 1)
            $encoded = Compress-Payload (Build-Payload $list $originalCount)
        }
    }

    Write-Output $encoded
    exit 0
}
catch {
    $msg = "$($_.Exception.Message)"
    if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
    $msg = ($msg -replace '[\|\r\n\t]', ' ').Trim()
    Write-Output "v1|error|$msg"
    exit 0
}
