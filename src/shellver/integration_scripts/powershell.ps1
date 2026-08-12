function global:_ShellverGetStateDirectory {
    $stateHome = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path $HOME '.local\state' }
    return Join-Path $stateHome 'shellver'
}

function global:_ShellverGetComponent {
    param([string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        return '-'
    }

    try {
        $reader = [IO.File]::OpenText($Path)
        try {
            $line = $reader.ReadLine()
            $value = if ($null -eq $line) { '' } else { $line.Trim() }
        } finally {
            $reader.Dispose()
        }
    } catch {
        return '-'
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        return '-'
    }
    return $value
}

function global:_ShellverGetCurrent {
    $stateDirectory = _ShellverGetStateDirectory
    $common = _ShellverGetComponent (Join-Path $stateDirectory 'common')
    $localGeneration = _ShellverGetComponent (Join-Path $stateDirectory 'local')
    $machine = _ShellverGetComponent (Join-Path $stateDirectory 'machine')
    return "common:$common|local:$localGeneration|machine:$machine"
}

function global:_ShellverIsStale {
    return $env:SHELLVER -cne (_ShellverGetCurrent)
}

function global:_ShellverPrintWarning {
    if ($env:NO_COLOR) {
        [Console]::WriteLine('[shellver stale]')
    } else {
        [Console]::WriteLine("$([char]27)[31m[shellver stale]$([char]27)[0m")
    }
}

if (-not (Test-Path Env:SHELLVER)) {
    $env:SHELLVER = _ShellverGetCurrent
}

if (-not $global:_SHELLVER_POWERSHELL_HOOKED) {
    $global:_ShellverInnerPrompt = (Get-Item Function:\prompt).ScriptBlock
    function global:prompt {
        $shellverLastSuccess = $?
        $shellverLastExitCode = $global:LASTEXITCODE
        if (_ShellverIsStale) {
            _ShellverPrintWarning
        }
        $global:LASTEXITCODE = $shellverLastExitCode
        if ($shellverLastSuccess) {
            $null = $true
            & $global:_ShellverInnerPrompt
        } else {
            Write-Error 'shellver-status-sentinel' -ErrorAction SilentlyContinue
            & $global:_ShellverInnerPrompt
        }
    }
    $global:_SHELLVER_POWERSHELL_HOOKED = $true
}
