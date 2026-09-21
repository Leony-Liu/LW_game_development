# Canonical Godot CLI wrapper for the Codex workspace.
#
# Goals:
# - Use Godot 4.7.2 for this workspace, independent of PATH.
# - Auto-discover the 4.7.2 Windows executable under D:\APP\Godot.
# - Prefer the console executable for reliable synchronous CLI behavior.
# - Run from the repository root.
# - Isolate automated Godot user/temp data under .codex_runtime/.
# - Forward arbitrary Godot CLI arguments and preserve the exit code.
#
# Optional override:
#   $env:GODOT_472_PATH = "D:\...\Godot_v4.7.2-stable_win64_console.exe"
#
# Examples:
#   .\tools\godot_cli.ps1 --version
#   .\tools\godot_cli.ps1 --headless --path . --quit
#   .\tools\godot_cli.ps1 --headless --editor --path . --quit

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredVersionPrefix = "4.7.2"
$GodotSearchRoot = "D:\APP\Godot"

# tools/godot_cli.ps1 -> repository root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "project.godot"
$RuntimeRoot = Join-Path $ProjectRoot ".codex_runtime"

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    throw "project.godot was not found at the expected repository root: $ProjectRoot"
}

function Resolve-GodotExecutable {
    # 1) Explicit override wins.
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_472_PATH)) {
        if (Test-Path -LiteralPath $env:GODOT_472_PATH -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:GODOT_472_PATH).Path
        }
        throw "GODOT_472_PATH is set but the file does not exist: $env:GODOT_472_PATH"
    }

    if (-not (Test-Path -LiteralPath $GodotSearchRoot -PathType Container)) {
        throw "Godot search root does not exist: $GodotSearchRoot"
    }

    # 2) Prefer the official console executable for 4.7.2.
    $Console = Get-ChildItem -LiteralPath $GodotSearchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '(?i)4\.7\.2.*console\.exe$' -or
            $_.Name -match '(?i)^godot.*console\.exe$' -and $_.DirectoryName -match '4\.7\.2'
        } |
        Sort-Object FullName |
        Select-Object -First 1

    if ($null -ne $Console) {
        return $Console.FullName
    }

    # 3) Fall back to the official GUI executable for 4.7.2.
    $Gui = Get-ChildItem -LiteralPath $GodotSearchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '(?i)4\.7\.2.*win64\.exe$' -and
            $_.Name -notmatch '(?i)console'
        } |
        Sort-Object FullName |
        Select-Object -First 1

    if ($null -ne $Gui) {
        return $Gui.FullName
    }

    throw "Godot 4.7.2 executable was not found under $GodotSearchRoot. Set GODOT_472_PATH to the exact executable path."
}

$GodotExe = Resolve-GodotExecutable
$UsingConsoleExe = [System.IO.Path]::GetFileName($GodotExe) -match '(?i)console'

# Isolated runtime/editor/temp directories for automated Codex runs.
$RoamingDir = Join-Path $RuntimeRoot "AppData\Roaming"
$LocalDir   = Join-Path $RuntimeRoot "AppData\Local"
$TempDir    = Join-Path $RuntimeRoot "Temp"

New-Item -ItemType Directory -Force -Path $RoamingDir, $LocalDir, $TempDir | Out-Null

$PreviousEnv = @{
    APPDATA      = $env:APPDATA
    LOCALAPPDATA = $env:LOCALAPPDATA
    TEMP         = $env:TEMP
    TMP          = $env:TMP
}

# Warn about a common false-positive source during editor validation.
if ($GodotArgs -contains "--editor") {
    $RunningGodot = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "Godot*" } |
        Select-Object -First 1
    if ($null -ne $RunningGodot) {
        Write-Warning "Another Godot process is already running. For a clean --editor validation, close the interactive editor first; MCP may otherwise contend for port 9876."
    }
}

try {
    $env:APPDATA      = $RoamingDir
    $env:LOCALAPPDATA = $LocalDir
    $env:TEMP         = $TempDir
    $env:TMP          = $TempDir

    Push-Location -LiteralPath $ProjectRoot
    try {
        Write-Host "[godot_cli] Godot: $GodotExe"
        Write-Verbose "Project root: $ProjectRoot"
        Write-Verbose "Codex runtime: $RuntimeRoot"

        $GodotExitCode = 0

        if ($UsingConsoleExe) {
            # Console-subsystem executable: synchronous, reliable exit code.
            $global:LASTEXITCODE = 0
            & $GodotExe @GodotArgs
            $GodotExitCode = $LASTEXITCODE
        }
        else {
            # GUI-subsystem fallback. Use Start-Process -Wait to obtain a real exit code.
            Write-Warning "Godot 4.7.2 console executable was not found; using GUI executable with Start-Process -Wait."
            $Process = Start-Process `
                -FilePath $GodotExe `
                -ArgumentList $GodotArgs `
                -WorkingDirectory $ProjectRoot `
                -Wait `
                -PassThru
            $GodotExitCode = $Process.ExitCode
        }

        if ($GodotExitCode -ne 0) {
            throw "Godot exited with code $GodotExitCode."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    foreach ($Name in $PreviousEnv.Keys) {
        $OldValue = $PreviousEnv[$Name]
        if ($null -eq $OldValue) {
            Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item "Env:$Name" $OldValue
        }
    }
}
