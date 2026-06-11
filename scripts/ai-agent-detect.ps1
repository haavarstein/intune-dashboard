# THE Intune Dashboard - AI Agent Scan (detection script)
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  INTUNE PORTAL METADATA — copy/paste into the "Add" wizard               ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║  Name        : THE Intune Dashboard - AI Agent Scan                      ║
# ║  Publisher   : THE Intune Dashboard                                      ║
# ║  Description :                                                           ║
# ║    Agentless AI-agent discovery (shadow-AI inventory). Scans every       ║
# ║    user profile and the machine for locally installed AI agents —       ║
# ║    Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, Claude/       ║
# ║    ChatGPT/Ollama/LM Studio/Poe desktop apps, Cursor, Windsurf, Cline,   ║
# ║    Roo Code, Continue, Aider, OpenCode — via WinGet packages, npm        ║
# ║    globals, desktop-app folders, VS Code extensions, agent config        ║
# ║    directories, machine-wide installs, and running processes. Reports    ║
# ║    a gzip+base64-encoded snapshot via the detection script's stdout      ║
# ║    channel. Read by THE Intune Dashboard's AI agents sub-tab as the      ║
# ║    fleet-scan fallback until Microsoft Defender's agent-discovery        ║
# ║    preview is enabled by default. Always exits 0; never remediates.      ║
# ║                                                                          ║
# ║    Privacy: this is a SECURITY inventory, so (unlike the metering        ║
# ║    script) the profile USERNAME is transmitted per detected agent.       ║
# ║    No file contents, prompts, or document names are collected — only    ║
# ║    agent name, vendor, version, username, detection channel, and         ║
# ║    integer days since the install artifact was created.                  ║
# ║                                                                          ║
# ║    Per-run progress is logged to:                                        ║
# ║    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs               ║
# ║      \IntuneDashboard-AiAgentScan.log                                    ║
# ║                                                                          ║
# ║    Source / setup: github.com/haavarstein/intune-dashboard               ║
# ║                                                                          ║
# ║  Settings:                                                               ║
# ║    Detection script file                       : this .ps1               ║
# ║    Remediation script file                     : (leave empty)           ║
# ║    Run this script using the logged-on creds   : No   (= SYSTEM)         ║
# ║    Enforce script signature check              : No                      ║
# ║    Run script in 64-bit PowerShell             : Yes                     ║
# ║    Assignment                                  : All Devices (or pilot)  ║
# ║    Schedule                                    : Daily                   ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
# Wire format (after gunzip + base64 decode):
#   v1|<ISO timestamp>[|truncated=KofN]
#   agent|vendor|ver|user|via|daysAgo
#   <rows...>
# user is '*' for machine-wide installs; daysAgo is days since the install
# artifact's creation time (-1 = unknown). via is the detection channel:
# winget|arp|desktop|npm|vscode|config|process.
# On any failure the script writes a plain-text sentinel instead of base64:
#   v1|error|<short message>

$ErrorActionPreference = 'Stop'
$MaxOutputBytes        = 1950   # ~2 KB cap on preRemediationDetectionScriptOutput
$LogDir                = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
$LogPath               = Join-Path $LogDir 'IntuneDashboard-AiAgentScan.log'
$LogMaxBytes           = 1MB    # rotate (truncate) when log exceeds this

# --- Logging ------------------------------------------------------------------
function Write-ScanLog {
    param([string]$Level, [string]$Message)
    try {
        if (-not (Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }
        if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt $LogMaxBytes) {
            $rotateLine = "$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) [INFO] === log rotated (exceeded $($LogMaxBytes/1KB) KB) ==="
            Set-Content -LiteralPath $LogPath -Value $rotateLine -Encoding UTF8
        }
        $line = "$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) [$Level] $Message"
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    } catch {}
}

# --- Detection catalog ----------------------------------------------------------
# Mirrors (and extends) Microsoft's supported local-AI-agent list from
# learn.microsoft.com/defender-endpoint/local-agent-discovery-overview.
# Detection-channel priority (lower = stronger evidence, wins the dedupe):
#   1 winget · 2 arp · 3 desktop · 4 npm · 5 vscode · 6 config · 7 process

$WingetPkgs = @(   # %LOCALAPPDATA%\Microsoft\WinGet\Packages\<Prefix>_*
    @{ Prefix = 'Anthropic.ClaudeCode'; Agent = 'Claude Code';        Vendor = 'Anthropic'; Exe = 'claude.exe' }
    @{ Prefix = 'OpenAI.Codex';         Agent = 'Codex CLI';          Vendor = 'OpenAI';    Exe = 'codex.exe' }
    @{ Prefix = 'Google.GeminiCLI';     Agent = 'Gemini CLI';         Vendor = 'Google';    Exe = 'gemini.exe' }
    @{ Prefix = 'GitHub.CopilotCLI';    Agent = 'GitHub Copilot CLI'; Vendor = 'GitHub';    Exe = 'copilot.exe' }
    @{ Prefix = 'Ollama.Ollama';        Agent = 'Ollama';             Vendor = 'Ollama';    Exe = 'ollama.exe' }
)
$DesktopApps = @(  # %LOCALAPPDATA%\Programs\<Dir>
    @{ Dir = 'Claude';    Agent = 'Claude Desktop';  Vendor = 'Anthropic';    Exe = 'claude.exe' }
    @{ Dir = 'ChatGPT';   Agent = 'ChatGPT Desktop'; Vendor = 'OpenAI';       Exe = 'ChatGPT.exe' }
    @{ Dir = 'cursor';    Agent = 'Cursor';          Vendor = 'Anysphere';    Exe = 'Cursor.exe' }
    @{ Dir = 'Windsurf';  Agent = 'Windsurf';        Vendor = 'Codeium';      Exe = 'Windsurf.exe' }
    @{ Dir = 'Ollama';    Agent = 'Ollama';          Vendor = 'Ollama';       Exe = 'ollama app.exe' }
    @{ Dir = 'LM Studio'; Agent = 'LM Studio';       Vendor = 'Element Labs'; Exe = 'LM Studio.exe' }
    @{ Dir = 'Poe';       Agent = 'Poe Desktop';     Vendor = 'Quora';        Exe = 'Poe.exe' }
)
$NpmPkgs = @(      # %APPDATA%\npm\node_modules\<Path>
    @{ Path = '@anthropic-ai\claude-code'; Agent = 'Claude Code';        Vendor = 'Anthropic' }
    @{ Path = '@openai\codex';             Agent = 'Codex CLI';          Vendor = 'OpenAI' }
    @{ Path = '@google\gemini-cli';        Agent = 'Gemini CLI';         Vendor = 'Google' }
    @{ Path = '@github\copilot';           Agent = 'GitHub Copilot CLI'; Vendor = 'GitHub' }
    @{ Path = 'opencode-ai';               Agent = 'OpenCode';           Vendor = 'OpenCode' }
)
$VsixPrefixes = @( # <profile>\.vscode\extensions\<prefix>-<version>
    @{ Prefix = 'anthropic.claude-code';    Agent = 'Claude Code (VS Code)'; Vendor = 'Anthropic' }
    @{ Prefix = 'saoudrizwan.claude-dev';   Agent = 'Cline';                 Vendor = 'Cline Bot' }
    @{ Prefix = 'rooveterinaryinc.roo';     Agent = 'Roo Code';              Vendor = 'Roo Code' }
    @{ Prefix = 'github.copilot-chat';      Agent = 'GitHub Copilot Chat';   Vendor = 'GitHub' }
    @{ Prefix = 'google.geminicodeassist';  Agent = 'Gemini Code Assist';    Vendor = 'Google' }
    @{ Prefix = 'continue.continue';        Agent = 'Continue';              Vendor = 'Continue' }
)
$ConfigDirs = @(   # <profile>\<Dir> — config artifacts survive even if the binary moved
    @{ Dir = '.claude';   Agent = 'Claude Code';        Vendor = 'Anthropic' }
    @{ Dir = '.codex';    Agent = 'Codex CLI';          Vendor = 'OpenAI' }
    @{ Dir = '.gemini';   Agent = 'Gemini CLI';         Vendor = 'Google' }
    @{ Dir = '.copilot';  Agent = 'GitHub Copilot CLI'; Vendor = 'GitHub' }
    @{ Dir = '.ollama';   Agent = 'Ollama';             Vendor = 'Ollama' }
    @{ Dir = '.cursor';   Agent = 'Cursor';             Vendor = 'Anysphere' }
    @{ Dir = '.windsurf'; Agent = 'Windsurf';           Vendor = 'Codeium' }
    @{ Dir = '.continue'; Agent = 'Continue';           Vendor = 'Continue' }
    @{ Dir = '.aider';    Agent = 'Aider';              Vendor = 'Aider' }
    @{ Dir = '.opencode'; Agent = 'OpenCode';           Vendor = 'OpenCode' }
)
$ArpPatterns = @(  # machine-wide HKLM uninstall entries
    @{ Rx = '^Ollama';     Agent = 'Ollama';          Vendor = 'Ollama' }
    @{ Rx = '^LM Studio';  Agent = 'LM Studio';       Vendor = 'Element Labs' }
    @{ Rx = '^Cursor';     Agent = 'Cursor';          Vendor = 'Anysphere' }
    @{ Rx = '^Windsurf';   Agent = 'Windsurf';        Vendor = 'Codeium' }
    @{ Rx = '^Claude($| )'; Agent = 'Claude Desktop'; Vendor = 'Anthropic' }
    @{ Rx = '^ChatGPT';    Agent = 'ChatGPT Desktop'; Vendor = 'OpenAI' }
)
$ProcMap = @{      # point-in-time running processes (catches portable/unknown installs)
    'claude'     = @{ Agent = 'Claude Code';     Vendor = 'Anthropic' }
    'ollama'     = @{ Agent = 'Ollama';          Vendor = 'Ollama' }
    'ollama app' = @{ Agent = 'Ollama';          Vendor = 'Ollama' }
    'cursor'     = @{ Agent = 'Cursor';          Vendor = 'Anysphere' }
    'windsurf'   = @{ Agent = 'Windsurf';        Vendor = 'Codeium' }
    'chatgpt'    = @{ Agent = 'ChatGPT Desktop'; Vendor = 'OpenAI' }
    'lm studio'  = @{ Agent = 'LM Studio';       Vendor = 'Element Labs' }
    'codex'      = @{ Agent = 'Codex CLI';       Vendor = 'OpenAI' }
    'gemini'     = @{ Agent = 'Gemini CLI';      Vendor = 'Google' }
}

# --- Helpers --------------------------------------------------------------------
function Get-DaysAgo {
    param($Item)
    try {
        $days = [int]([System.DateTime]::UtcNow - $Item.CreationTimeUtc).TotalDays
        if ($days -lt 0) { $days = 0 }
        return $days
    } catch { return -1 }
}

function Get-ExeVersion {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $v = (Get-Item $Path).VersionInfo.ProductVersion
            if ($v) { return "$v".Trim() }
        }
    } catch {}
    return ''
}

function Get-NpmVersion {
    param([string]$PkgDir)
    try {
        $pj = Join-Path $PkgDir 'package.json'
        if (Test-Path $pj) {
            $m = [regex]::Match((Get-Content -LiteralPath $pj -Raw), '"version"\s*:\s*"([^"]+)"')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    } catch {}
    return ''
}

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
    [void]$sb.AppendLine('agent|vendor|ver|user|via|daysAgo')
    foreach ($r in $Rows) { [void]$sb.AppendLine($r.Line) }
    return $sb.ToString().TrimEnd("`r`n".ToCharArray())
}

# --- Main -----------------------------------------------------------------------
try {
    $osVer = try { [System.Environment]::OSVersion.Version.ToString() } catch { '?' }
    $psVer = $PSVersionTable.PSVersion.ToString()
    Write-ScanLog 'INFO' "=== Run started · schema v1 · PS $psVer · OS $osVer ==="

    # Dedupe on agent|user; lower Rank = stronger evidence wins via/version;
    # DaysAgo keeps the OLDEST artifact (best install-date proxy).
    $found = @{}
    function Add-Hit {
        param([string]$Agent, [string]$Vendor, [string]$Version, [string]$User, [string]$Via, [int]$Rank, [int]$DaysAgo)
        $key = "$Agent|$User".ToLowerInvariant()
        if (-not $found.ContainsKey($key)) {
            $found[$key] = [PSCustomObject]@{ Agent = $Agent; Vendor = $Vendor; Version = $Version; User = $User; Via = $Via; Rank = $Rank; DaysAgo = $DaysAgo }
            return
        }
        $cur = $found[$key]
        if ($Rank -lt $cur.Rank) { $cur.Via = $Via; $cur.Rank = $Rank; if ($Version) { $cur.Version = $Version } }
        elseif (-not $cur.Version -and $Version) { $cur.Version = $Version }
        if ($DaysAgo -ge 0 -and $DaysAgo -gt $cur.DaysAgo) { $cur.DaysAgo = $DaysAgo }
    }

    # --- Per-user profile sweeps (runs as SYSTEM, so every profile is readable)
    $profiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0') }
    $profileCount = 0
    foreach ($p in $profiles) {
        $profileCount++
        $user = $p.Name

        foreach ($w in $WingetPkgs) {
            foreach ($pkg in (Get-ChildItem (Join-Path $p.FullName 'AppData\Local\Microsoft\WinGet\Packages') -Directory -Filter "$($w.Prefix)_*" -ErrorAction SilentlyContinue)) {
                $ver = Get-ExeVersion (Join-Path $pkg.FullName $w.Exe)
                Add-Hit $w.Agent $w.Vendor $ver $user 'winget' 1 (Get-DaysAgo $pkg)
            }
        }
        foreach ($d in $DesktopApps) {
            $dir = Join-Path $p.FullName "AppData\Local\Programs\$($d.Dir)"
            if (Test-Path $dir) {
                $ver = Get-ExeVersion (Join-Path $dir $d.Exe)
                Add-Hit $d.Agent $d.Vendor $ver $user 'desktop' 3 (Get-DaysAgo (Get-Item $dir))
            }
        }
        foreach ($n in $NpmPkgs) {
            $dir = Join-Path $p.FullName "AppData\Roaming\npm\node_modules\$($n.Path)"
            if (Test-Path $dir) {
                Add-Hit $n.Agent $n.Vendor (Get-NpmVersion $dir) $user 'npm' 4 (Get-DaysAgo (Get-Item $dir))
            }
        }
        $extRoot = Join-Path $p.FullName '.vscode\extensions'
        if (Test-Path $extRoot) {
            foreach ($v in $VsixPrefixes) {
                foreach ($ext in (Get-ChildItem $extRoot -Directory -Filter "$($v.Prefix)*" -ErrorAction SilentlyContinue)) {
                    $ver = ''
                    $m = [regex]::Match($ext.Name, '-(\d+(?:\.\d+)+)$')
                    if ($m.Success) { $ver = $m.Groups[1].Value }
                    Add-Hit $v.Agent $v.Vendor $ver $user 'vscode' 5 (Get-DaysAgo $ext)
                }
            }
        }
        foreach ($c in $ConfigDirs) {
            $dir = Join-Path $p.FullName $c.Dir
            if (Test-Path $dir) {
                Add-Hit $c.Agent $c.Vendor '' $user 'config' 6 (Get-DaysAgo (Get-Item $dir))
            }
        }
    }

    # --- Machine-wide ARP entries (user = '*')
    $arpPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($entry in (Get-ItemProperty -Path $arpPaths -ErrorAction SilentlyContinue)) {
        if (-not $entry.DisplayName) { continue }
        foreach ($a in $ArpPatterns) {
            if ($entry.DisplayName -match $a.Rx) {
                $ver = ''
                if ($entry.DisplayVersion) { $ver = "$($entry.DisplayVersion)".Trim() }
                $days = -1
                if ($entry.InstallDate -and "$($entry.InstallDate)" -match '^\d{8}$') {
                    try {
                        $dt = [System.DateTime]::ParseExact("$($entry.InstallDate)", 'yyyyMMdd', $null)
                        $days = [int]([System.DateTime]::UtcNow - $dt).TotalDays
                        if ($days -lt 0) { $days = -1 }
                    } catch {}
                }
                Add-Hit $a.Agent $a.Vendor $ver '*' 'arp' 2 $days
                break
            }
        }
    }

    # --- Running processes (catches portable installs the file sweeps miss).
    # -IncludeUserName needs elevation (true as SYSTEM under IME); fall back
    # to anonymous process names rather than failing the whole run.
    $procs = @()
    try { $procs = @(Get-Process -IncludeUserName -ErrorAction Stop) }
    catch {
        Write-ScanLog 'WARN' 'Get-Process -IncludeUserName unavailable (not elevated?); process hits will have no username'
        try { $procs = @(Get-Process -ErrorAction Stop) } catch { $procs = @() }
    }
    foreach ($proc in $procs) {
        $pname = $proc.ProcessName.ToLowerInvariant()
        if (-not $ProcMap.ContainsKey($pname)) { continue }
        $m = $ProcMap[$pname]
        $user = '*'
        if ($proc.PSObject.Properties['UserName'] -and $proc.UserName) { $user = $proc.UserName.Split('\')[-1] }
        if ($user -in @('SYSTEM', 'LOCAL SERVICE', 'NETWORK SERVICE')) { $user = '*' }
        $ver = ''
        try { if ($proc.Path) { $ver = Get-ExeVersion $proc.Path } } catch {}
        Add-Hit $m.Agent $m.Vendor $ver $user 'process' 7 -1
    }

    # --- Serialize: newest installs first; oldest dropped first under byte pressure
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($hit in ($found.Values | Sort-Object @{Expression = { if ($_.DaysAgo -lt 0) { [int]::MaxValue } else { $_.DaysAgo } }}, Agent)) {
        $line = '{0}|{1}|{2}|{3}|{4}|{5}' -f (Format-Field $hit.Agent), (Format-Field $hit.Vendor), (Format-Field $hit.Version), (Format-Field $hit.User), $hit.Via, $hit.DaysAgo
        $rows.Add([PSCustomObject]@{ Line = $line })
    }
    $sorted = $rows.ToArray()
    $originalCount = $sorted.Count
    Write-ScanLog 'INFO' "Agents found: $originalCount unique (agent × user) across $profileCount profile(s)"

    $encoded = Compress-Payload (Build-Payload $sorted $originalCount)
    $initialEncodedLen = $encoded.Length
    if ($encoded.Length -gt $MaxOutputBytes) {
        $list = New-Object System.Collections.Generic.List[object]
        $list.AddRange($sorted)
        while ($encoded.Length -gt $MaxOutputBytes -and $list.Count -gt 0) {
            $list.RemoveAt($list.Count - 1)
            $encoded = Compress-Payload (Build-Payload $list $originalCount)
        }
        Write-ScanLog 'WARN' "Payload truncated: kept $($list.Count) of $originalCount rows · $initialEncodedLen → $($encoded.Length) bytes (cap $MaxOutputBytes)"
    } else {
        Write-ScanLog 'INFO' "Payload: $originalCount rows · $($encoded.Length) bytes base64-gzip (cap $MaxOutputBytes)"
    }

    Write-Output $encoded
    Write-ScanLog 'INFO' '=== Run completed ==='
    exit 0
}
catch {
    $msg = "$($_.Exception.Message)"
    $where = if ($_.InvocationInfo) { " at line $($_.InvocationInfo.ScriptLineNumber)" } else { '' }
    Write-ScanLog 'ERROR' "Run failed: $msg$where"
    if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
    $msg = ($msg -replace '[\|\r\n\t]', ' ').Trim()
    Write-Output "v1|error|$msg"
    exit 0
}
