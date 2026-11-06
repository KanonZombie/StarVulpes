# Full build: extraction from the Star Fox ROM (extract_sf.ps1) and assembly
# (build.ps1). -Target selects the ROM as in build.ps1.
param(
    [ValidateSet('m4-intro', 'm4-level-boss', 'm4-level-profile', 'm4-intro-vr-stress')][string]$Target = 'm4-intro',
    [string]$Asm68k = $env:MEGASVP_ASM68K,
    [string]$MusicManifest
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.2') {
    & (Join-Path $PSScriptRoot 'tools/run-pwsh.ps1') $PSCommandPath $PSBoundParameters
    return
}
if ($MusicManifest) {
    if ($Target -ne 'm4-intro') { throw '-MusicManifest requiere el objetivo m4-intro.' }
    if (-not (Test-Path -LiteralPath $MusicManifest -PathType Leaf)) { throw "Falta el manifiesto: $MusicManifest" }
}
. (Join-Path $PSScriptRoot 'tools/stage-common.ps1')
$buildMutex = Enter-MegaSvpBuildLock $PSScriptRoot
try {
    foreach ($name in "megasvp-$Target.bin", "$Target-build.json") {
        $outputPath = Join-Path $PSScriptRoot "build/$name"
        if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
            Remove-Item -LiteralPath $outputPath -Force
        }
    }
    & (Join-Path $PSScriptRoot 'extract_sf.ps1')
    & (Join-Path $PSScriptRoot 'build.ps1') -Target $Target -Asm68k $Asm68k -MusicManifest $MusicManifest
} finally {
    $buildMutex.ReleaseMutex()
    $buildMutex.Dispose()
}
