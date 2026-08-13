$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)

    if ($Expected -cne $Actual) {
        throw "$Message. Expected '$Expected', got '$Actual'"
    }
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "shellver-hooks-$([guid]::NewGuid())"
$previousPythonPath = $env:PYTHONPATH
$previousConfigHome = $env:XDG_CONFIG_HOME
$previousStateHome = $env:XDG_STATE_HOME
$previousShellver = $env:SHELLVER
$hadShellver = Test-Path Env:SHELLVER

try {
    $configHome = Join-Path $testRoot 'config'
    $stateHome = Join-Path $testRoot 'state'
    $configDirectory = Join-Path $configHome 'shellver'
    $stateDirectory = Join-Path $stateHome 'shellver'
    [IO.Directory]::CreateDirectory($configDirectory) | Out-Null
    [IO.Directory]::CreateDirectory($stateDirectory) | Out-Null
    [IO.File]::WriteAllText((Join-Path $configDirectory 'common'), "1`n")
    [IO.File]::WriteAllText((Join-Path $configDirectory 'local'), "4`n")
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'machine'), "7`n")
    $env:PYTHONPATH = Join-Path $projectRoot 'src'
    $env:XDG_CONFIG_HOME = $configHome
    $env:XDG_STATE_HOME = $stateHome
    Remove-Item Env:SHELLVER -ErrorAction SilentlyContinue

    function global:prompt {
        "inner:$($?):$global:LASTEXITCODE"
    }
    $originalPrompt = (Get-Item Function:\prompt).ScriptBlock.ToString()

    $hookCode = & python -m shellver init powershell | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "shellver init powershell failed with exit code $LASTEXITCODE"
    }
    Invoke-Expression $hookCode
    Invoke-Expression $hookCode

    Assert-Equal 'common:1|local:4|machine:7' $env:SHELLVER 'Initial snapshot mismatch'
    Assert-Equal $originalPrompt (Get-Item Function:\prompt).ScriptBlock.ToString() 'Init changed the prompt function'
    Assert-Equal $env:SHELLVER (Get-ShellverCurrent) 'Current-generation function mismatch'
    Assert-Equal $false (Test-ShellverStale) 'Current shell reported stale'
    [IO.File]::WriteAllText((Join-Path $configDirectory 'common'), "2`n")
    Assert-Equal $true (Test-ShellverStale) 'Stale shell reported current'
    Assert-Equal 'common:2|local:4|machine:7' (Get-ShellverCurrent) 'Updated generation mismatch'
    [IO.File]::WriteAllText((Join-Path $configDirectory 'machine'), "99`n")
    try {
        Get-ShellverCurrent | Out-Null
        throw 'Reserved machine generation was accepted'
    } catch {
        if (-not $_.Exception.Message.Contains("reserved generation name 'machine'")) {
            throw
        }
    }
    Write-Host 'PASS: shellver PowerShell capabilities'
} finally {
    if ($null -eq $previousPythonPath) { Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue } else { $env:PYTHONPATH = $previousPythonPath }
    if ($null -eq $previousConfigHome) { Remove-Item Env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue } else { $env:XDG_CONFIG_HOME = $previousConfigHome }
    if ($null -eq $previousStateHome) { Remove-Item Env:XDG_STATE_HOME -ErrorAction SilentlyContinue } else { $env:XDG_STATE_HOME = $previousStateHome }
    if ($hadShellver) { $env:SHELLVER = $previousShellver } else { Remove-Item Env:SHELLVER -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
