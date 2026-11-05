# Entry point for PowerShell. The interpreter itself is bf_interpreter.js.

if (-not (Get-Command node -CommandType Application -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('bf: Node.js não encontrado. Instale em https://nodejs.org e tente de novo.')
    exit 127
}

$engine = Join-Path $PSScriptRoot '..\bf_interpreter.js'
$utf8 = New-Object System.Text.UTF8Encoding $false

# Brainfuck programs emit raw bytes. Without this, the console and PowerShell's pipes would
# decode them with the legacy code page and corrupt anything that is not ASCII.
# When piping to a native program, PowerShell only honors the global $OutputEncoding.
$previousOutputEncoding = $global:OutputEncoding
$global:OutputEncoding = $utf8
$previousConsoleEncoding = $null
try {
    $previousConsoleEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = $utf8
} catch {
    # No console attached (e.g. a background job). There is nothing to configure.
}

try {
    # Piping an empty $input would close stdin, so it is only forwarded when there is a pipeline.
    if ($MyInvocation.ExpectingInput) {
        $input | & node $engine @args
    } else {
        & node $engine @args
    }
    $exitCode = $LASTEXITCODE
} finally {
    $global:OutputEncoding = $previousOutputEncoding
    if ($previousConsoleEncoding) {
        try { [Console]::OutputEncoding = $previousConsoleEncoding } catch { }
    }
}

exit $exitCode
