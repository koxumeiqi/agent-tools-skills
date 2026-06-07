$ErrorActionPreference = "Stop"

$skillsRoot = "C:\Users\myz03\.codex\skills"
$pluginsRoot = "C:\Users\myz03\plugins"
$repoRoot = "C:\Users\myz03\Documents\Codex\2026-06-07\github-cli\agent-tools-skills"
$repoSkillRoot = Join-Path $repoRoot ".codex\skill"
$repoPluginRoot = Join-Path $repoRoot ".codex\plugin"
$logPath = "C:\Users\myz03\.codex\tmp\codex-skill-sync.log"

function Write-Log {
    param([string]$Message)
    $logDir = Split-Path -Parent $logPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force $logDir | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Encoding UTF8 -Path $logPath -Value "[$timestamp] $Message"
}

function Normalize-Path {
    param([string]$Path)
    try {
        return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\', '/').ToLowerInvariant()
    } catch {
        return $null
    }
}

function Read-HookPayload {
    if ([Console]::IsInputRedirected) {
        $payload = [Console]::In.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($payload)) {
            return $payload
        }
    }

    foreach ($name in @("CODEX_HOOK_INPUT", "CODEX_TOOL_INPUT", "CODEX_EVENT_JSON")) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return ""
}

function Get-ChangedPathsFromPayload {
    param([string]$Payload)

    $paths = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Payload)) {
        return $paths
    }

    try {
        $json = $Payload | ConvertFrom-Json -Depth 20
        $stack = New-Object System.Collections.Stack
        $stack.Push($json)

        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            if ($null -eq $node) { continue }

            if ($node -is [string]) {
                if ($node -match '^[A-Za-z]:[\\/]' -or $node -like "*\.codex*skills*" -or $node -like "*\plugins*") {
                    $paths.Add($node)
                }
                continue
            }

            if ($node -is [System.Collections.IEnumerable] -and -not ($node -is [string])) {
                foreach ($item in $node) { $stack.Push($item) }
                continue
            }

            foreach ($prop in $node.PSObject.Properties) {
                if ($prop.Name -match 'path|file') {
                    if ($prop.Value -is [string]) {
                        $paths.Add($prop.Value)
                    } else {
                        $stack.Push($prop.Value)
                    }
                } else {
                    $stack.Push($prop.Value)
                }
            }
        }
    } catch {
        foreach ($match in [regex]::Matches($Payload, '[A-Za-z]:[\\/][^"''\r\n]+')) {
            $paths.Add($match.Value)
        }
    }

    return $paths
}

function Test-PathIsUserSkill {
    param([string]$Path)

    $normalizedRoot = Normalize-Path $skillsRoot
    $normalizedPath = Normalize-Path $Path
    if ($null -eq $normalizedPath) { return $false }
    if (-not $normalizedPath.StartsWith($normalizedRoot)) { return $false }
    if ($normalizedPath.StartsWith((Normalize-Path (Join-Path $skillsRoot ".system")))) { return $false }
    return $true
}

function Test-PathIsUserPlugin {
    param([string]$Path)

    $normalizedRoot = Normalize-Path $pluginsRoot
    $normalizedPath = Normalize-Path $Path
    if ($null -eq $normalizedPath) { return $false }
    if (-not $normalizedPath.StartsWith($normalizedRoot)) { return $false }
    return $true
}

function Sync-DirectoriesToRepo {
    param(
        [bool]$SyncSkills,
        [bool]$SyncPlugins
    )

    if (-not (Test-Path $repoRoot)) {
        Write-Log "repo root missing: $repoRoot"
        return 1
    }

    if ($SyncSkills -and -not (Test-Path $repoSkillRoot)) {
        New-Item -ItemType Directory -Force $repoSkillRoot | Out-Null
    }

    if ($SyncPlugins -and -not (Test-Path $repoPluginRoot)) {
        New-Item -ItemType Directory -Force $repoPluginRoot | Out-Null
    }

    if ($SyncSkills) {
        Get-ChildItem -Path $skillsRoot -Directory -Force |
            Where-Object { $_.Name -ne ".system" } |
            ForEach-Object {
                $destination = Join-Path $repoSkillRoot $_.Name
                if (Test-Path $destination) {
                    Remove-Item -LiteralPath $destination -Recurse -Force
                }
                Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
            }
    }

    if ($SyncPlugins) {
        Get-ChildItem -Path $pluginsRoot -Directory -Force |
            ForEach-Object {
                $destination = Join-Path $repoPluginRoot $_.Name
                if (Test-Path $destination) {
                    Remove-Item -LiteralPath $destination -Recurse -Force
                }
                Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
            }
    }

    Push-Location $repoRoot
    try {
        $status = git status --short
        if ([string]::IsNullOrWhiteSpace(($status -join "`n"))) {
            Write-Log "no git changes after sync"
            return 0
        }

        if ($SyncSkills) {
            git add .codex/skill | Out-Null
        }
        if ($SyncPlugins) {
            git add .codex/plugin | Out-Null
        }

        $targets = @()
        if ($SyncSkills) { $targets += "skills" }
        if ($SyncPlugins) { $targets += "plugins" }
        $message = "Sync Codex $($targets -join ' and ') $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git -c user.name='koxumeiqi' -c user.email='koxumeiqi@users.noreply.github.com' commit -m $message | Out-Null
        git push | Out-Null
        Write-Log "synced Codex $($targets -join ' and ') to GitHub"
        return 0
    } finally {
        Pop-Location
    }
}

try {
    $payload = Read-HookPayload
    $changedPaths = Get-ChangedPathsFromPayload $payload

    if ($changedPaths.Count -eq 0) {
        Write-Log "hook skipped: no changed path in payload"
        exit 0
    }

    $syncSkills = $false
    $syncPlugins = $false
    foreach ($path in $changedPaths) {
        if (Test-PathIsUserSkill $path) {
            $syncSkills = $true
        }
        if (Test-PathIsUserPlugin $path) {
            $syncPlugins = $true
        }
    }

    if (-not $syncSkills -and -not $syncPlugins) {
        Write-Log "hook skipped: changed paths outside user skills/plugins"
        exit 0
    }

    exit (Sync-DirectoriesToRepo -SyncSkills:$syncSkills -SyncPlugins:$syncPlugins)
} catch {
    Write-Log "sync failed: $($_.Exception.Message)"
    exit 0
}
