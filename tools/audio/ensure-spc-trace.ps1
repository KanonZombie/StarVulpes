# Verify the converter included in the checkout; no download or compilation.
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'spc-trace.json') -Raw | ConvertFrom-Json
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'El extractor SPC precompilado requiere Windows x64.'
}
$binary = Join-Path $PSScriptRoot 'spc-trace.exe'
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
    throw 'Falta tools/audio/spc-trace.exe. Restaure el archivo desde el checkout.'
}
if ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.sha256) {
    throw 'SHA-256 incorrecto de tools/audio/spc-trace.exe. Restaure el archivo desde el checkout.'
}
Write-Host "Extractor SPC $($manifest.version) del checkout verificado."
