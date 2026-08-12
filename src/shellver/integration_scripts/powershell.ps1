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

function global:Get-ShellverCurrent {
    $stateDirectory = _ShellverGetStateDirectory
    $common = _ShellverGetComponent (Join-Path $stateDirectory 'common')
    $localGeneration = _ShellverGetComponent (Join-Path $stateDirectory 'local')
    $machine = _ShellverGetComponent (Join-Path $stateDirectory 'machine')
    return "common:$common|local:$localGeneration|machine:$machine"
}

function global:Test-ShellverStale {
    return $env:SHELLVER -cne (Get-ShellverCurrent)
}

if (-not (Test-Path Env:SHELLVER)) {
    $env:SHELLVER = Get-ShellverCurrent
}
