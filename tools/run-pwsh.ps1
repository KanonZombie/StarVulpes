# Relaunch a build entry point invoked by Windows PowerShell.
param([string]$ScriptPath, [System.Collections.IDictionary]$BoundArguments)
$ErrorActionPreference = 'Stop'

# An old pwsh on PATH can reach this check after relaunch. Fail there once.
if ($PSVersionTable['PSEdition'] -ne 'Desktop') {
    throw 'Se requiere PowerShell 7.2 o posterior.'
}

$pwsh = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'PowerShell/7/pwsh.exe'
if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) {
    $command = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Instala PowerShell 7.2 o posterior para ejecutar el build.' }
    $pwsh = $command.Source
}

$forwarded = @(foreach ($binding in $BoundArguments.GetEnumerator()) {
    if ($binding.Value) { "-$($binding.Key):$($binding.Value)" }
})
Write-Host 'Continuando en PowerShell 7.'
& $pwsh -NoLogo -NoProfile -File $ScriptPath @forwarded
if ($LASTEXITCODE -ne 0) { throw "PowerShell 7 termino con codigo $LASTEXITCODE." }
