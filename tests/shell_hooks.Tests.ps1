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
$previousNoColor = $env:NO_COLOR
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
    $env:NO_COLOR = '1'
    Remove-Item Env:SHELLVER -ErrorAction SilentlyContinue

    function global:prompt {
        "inner:$($?):$global:LASTEXITCODE"
    }

    $hookCode = & python -m shellver init powershell | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "shellver init powershell failed with exit code $LASTEXITCODE"
    }
    Invoke-Expression $hookCode
    Invoke-Expression $hookCode

    Assert-Equal 'common:1|local:4|machine:machine-a' $env:SHELLVER 'Initial snapshot mismatch'
    [IO.File]::WriteAllText((Join-Path $shellverDirectory 'common'), "2`n")

    $writer = [IO.StringWriter]::new()
    $previousWriter = [Console]::Out
    try {
        [Console]::SetOut($writer)
        $global:LASTEXITCODE = 7
        Write-Error 'set failure status' -ErrorAction SilentlyContinue
        $renderedPrompt = prompt
    } finally {
        [Console]::SetOut($previousWriter)
    }

    Assert-Equal 'inner:False:7' $renderedPrompt 'Existing prompt state was not preserved'
    Assert-Equal 1 ([regex]::Matches($writer.ToString(), '\[shellver stale\]').Count) 'Hook was registered more than once'
    Write-Host 'PASS: shellver PowerShell hook'
} finally {
    if ($null -eq $previousPythonPath) { Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue } else { $env:PYTHONPATH = $previousPythonPath }
    if ($null -eq $previousStateHome) { Remove-Item Env:XDG_STATE_HOME -ErrorAction SilentlyContinue } else { $env:XDG_STATE_HOME = $previousStateHome }
    if ($null -eq $previousNoColor) { Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue } else { $env:NO_COLOR = $previousNoColor }
    if ($hadShellver) { $env:SHELLVER = $previousShellver } else { Remove-Item Env:SHELLVER -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $testStateRoot) { Remove-Item -LiteralPath $testStateRoot -Recurse -Force }
}
