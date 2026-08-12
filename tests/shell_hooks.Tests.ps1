$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)

    if ($Expected -cne $Actual) {
        throw "$Message. Expected '$Expected', got '$Actual'"
    }
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$testStateRoot = Join-Path ([IO.Path]::GetTempPath()) "shellver-hooks-$([guid]::NewGuid())"
$previousPythonPath = $env:PYTHONPATH
$previousStateHome = $env:XDG_STATE_HOME
$previousShellver = $env:SHELLVER
$hadShellver = Test-Path Env:SHELLVER

try {
    $shellverDirectory = Join-Path $testStateRoot 'shellver'
    [IO.Directory]::CreateDirectory($shellverDirectory) | Out-Null
    [IO.File]::WriteAllText((Join-Path $shellverDirectory 'common'), "1`n")
    [IO.File]::WriteAllText((Join-Path $shellverDirectory 'local'), "4`n")
    [IO.File]::WriteAllText((Join-Path $shellverDirectory 'machine'), "machine-a`n")
    $env:PYTHONPATH = Join-Path $projectRoot 'src'
    $env:XDG_STATE_HOME = $testStateRoot
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

    Assert-Equal 'common:1|local:4|machine:machine-a' $env:SHELLVER 'Initial snapshot mismatch'
    Assert-Equal $originalPrompt (Get-Item Function:\prompt).ScriptBlock.ToString() 'Init changed the prompt function'
    Assert-Equal $env:SHELLVER (Get-ShellverCurrent) 'Current-generation function mismatch'
    Assert-Equal $false (Test-ShellverStale) 'Current shell reported stale'
    [IO.File]::WriteAllText((Join-Path $shellverDirectory 'common'), "2`n")
    Assert-Equal $true (Test-ShellverStale) 'Stale shell reported current'
    Assert-Equal 'common:2|local:4|machine:machine-a' (Get-ShellverCurrent) 'Updated generation mismatch'
    Write-Host 'PASS: shellver PowerShell capabilities'
} finally {
    if ($null -eq $previousPythonPath) { Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue } else { $env:PYTHONPATH = $previousPythonPath }
    if ($null -eq $previousStateHome) { Remove-Item Env:XDG_STATE_HOME -ErrorAction SilentlyContinue } else { $env:XDG_STATE_HOME = $previousStateHome }
    if ($hadShellver) { $env:SHELLVER = $previousShellver } else { Remove-Item Env:SHELLVER -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $testStateRoot) { Remove-Item -LiteralPath $testStateRoot -Recurse -Force }
}
