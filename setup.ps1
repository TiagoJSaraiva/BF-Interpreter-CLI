# Adds the bin folder to the current user's PATH on Windows. Safe to run more than once.

$binDir = Join-Path $PSScriptRoot 'bin'

function Test-PathEntry($entries, $dir) {
    foreach ($entry in $entries) {
        if ($entry.TrimEnd('\', '/') -ieq $dir.TrimEnd('\', '/')) { return $true }
    }
    return $false
}

# Reads and writes the registry directly. [Environment]::GetEnvironmentVariable would expand
# entries such as %JAVA_HOME%\bin, and writing the result back would freeze their current value.
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
try {
    $userPath = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $entries = @($userPath -split ';' | Where-Object { $_ })

    if (Test-PathEntry $entries $binDir) {
        Write-Output "O PATH do usuário já contém $binDir"
    } else {
        $key.SetValue('Path', (($entries + $binDir) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
        Write-Output "Adicionado ao PATH do usuário: $binDir"

        # Removing an unset variable changes nothing, but makes Windows notify open programs.
        [Environment]::SetEnvironmentVariable('BF_SETUP_REFRESH', $null, 'User')
    }
} finally {
    $key.Close()
}

# Makes `bf` available in this session too.
if (-not (Test-PathEntry @($env:Path -split ';' | Where-Object { $_ }) $binDir)) {
    $env:Path = "$($env:Path.TrimEnd(';'));$binDir"
}

if (-not (Get-Command node -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Warning 'Node.js não encontrado. O comando bf precisa dele: https://nodejs.org'
}

# The Process scope is skipped because `-ExecutionPolicy Bypass` on this script would hide
# the policy that `bf.ps1` will face in a normal session.
$policy = 'Undefined'
foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
    $policy = [string](Get-ExecutionPolicy -Scope $scope)
    if ($policy -ne 'Undefined') { break }
}
if ($policy -in 'Undefined', 'Restricted', 'AllSigned') {
    Write-Warning "A execution policy atual ($policy) pode impedir o PowerShell de executar bf.ps1."
    Write-Warning 'Para liberar scripts locais: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

Write-Output "Pronto. Teste em um terminal novo: bf '++++++++[>++++++++<-]>+.'"
