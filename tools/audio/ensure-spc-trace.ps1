# Download only the pinned offline converter; never compile or execute a fallback.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'spc-trace.json') -Raw | ConvertFrom-Json
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'El extractor SPC precompilado requiere Windows x64.'
}
$out = Join-Path $root 'build/audio-native'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$binary = Join-Path $out 'spc-trace.exe'
if (Test-Path -LiteralPath $binary -PathType Leaf) {
    if ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.sha256) {
        throw "SHA-256 incorrecto del extractor SPC existente. Elimine $binary y repita la extraccion."
    }
    Write-Host "Extractor SPC $($manifest.version) verificado."
    return
}
$pending = Join-Path $out ('spc-trace-' + [Guid]::NewGuid().ToString('N') + '.download')
try {
    Write-Host "Descargando extractor SPC $($manifest.version)..."
    Invoke-WebRequest -Uri $manifest.url -OutFile $pending -TimeoutSec 120
    if ((Get-FileHash -LiteralPath $pending -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.sha256) {
        throw 'SHA-256 incorrecto de la descarga del extractor SPC. No se ejecutara.'
    }
    Move-Item -LiteralPath $pending -Destination $binary
    Write-Host "Extractor SPC $($manifest.version) descargado y verificado."
} finally {
    if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending }
}
