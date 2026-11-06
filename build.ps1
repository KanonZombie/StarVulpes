param(
    # The official game target includes MDSDRV.
    [ValidateSet('m4-intro', 'm4-level-boss', 'm4-level-profile', 'm4-intro-vr-stress')][string]$Target = 'm4-intro',
    [string]$Asm68k = $env:MEGASVP_ASM68K,
    [string]$MusicManifest
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.2') {
    & (Join-Path $PSScriptRoot 'tools/run-pwsh.ps1') $PSCommandPath $PSBoundParameters
    return
}
Set-StrictMode -Version Latest
if ($MusicManifest -and $Target -ne 'm4-intro') { throw '-MusicManifest requiere el objetivo m4-intro.' }
# Assembly only: build/ must already hold the data extracted from the Star Fox
# ROM (extract_sf.ps1; rebuild.ps1 runs both stages).
. (Join-Path $PSScriptRoot 'tools/stage-common.ps1')
$buildMutex = Enter-MegaSvpBuildLock $PSScriptRoot
$previousAssembler = $env:MEGASVP_ASM68K
try {
$projectRoot = $PSScriptRoot
$buildDir = Join-Path $projectRoot 'build'
$romName = Get-MegaSvpRomName $projectRoot $Target
$romPath = Join-Path $buildDir $romName
$manifestPath = Join-Path $buildDir "$Target-build.json"
$pendingPath = Join-Path $buildDir "$Target.pending.bin"
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
# Invalidate published output even when dependency validation fails.
foreach ($file in @($romPath, $manifestPath, $pendingPath)) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
}
$Asm68k = Resolve-MegaSvpAsm68k $projectRoot $Asm68k
$env:MEGASVP_ASM68K = $Asm68k
$sourceDir = Join-Path $projectRoot 'src'
$entry = switch ($Target) {
    # Profile layout plus the graphics117 lots (src/release/, M4_GRAPHICS117).
    'm4-intro' { 'main_release.asm' }
    'm4-level-boss' { 'main_level_boss.asm' }
    'm4-level-profile' { 'main_level_profile.asm' }
    'm4-intro-vr-stress' { 'main_vr_stress.asm' }
}
$stampPath = Join-Path $buildDir 'extract-sf.json'
if (-not (Test-Path -LiteralPath $stampPath)) {
    throw 'Faltan los datos extraidos de la ROM de Star Fox en build/. Ejecute extract_sf.ps1 (o rebuild.ps1).'
}
$stamp = Get-Content -LiteralPath $stampPath -Raw | ConvertFrom-Json
if ($stamp.starfox_sha256 -ne $MegaSvpStarFoxSha256) { throw 'build/ se extrajo de otra ROM de Star Fox. Ejecute extract_sf.ps1.' }
if ($stamp.inputs_sha256 -ne (Get-MegaSvpExtractionInputsHash $projectRoot)) {
    throw 'Los datos de build/ estan desactualizados: tools/ cambio desde la ultima extraccion. Ejecute extract_sf.ps1 (o rebuild.ps1).'
}
$hudPython = Resolve-MegaSvpPython $projectRoot
& $hudPython (Join-Path $projectRoot 'tools/generate-level-hud.py')
if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion del HUD desde build/level-hud.json.' }
& $hudPython (Join-Path $projectRoot 'tools/pack-backgrounds.py')
if ($LASTEXITCODE -ne 0) { throw 'Fallo el empaquetado de graficos extraidos.' }
if ($Target -eq 'm4-intro') {
    $releasePython = Resolve-MegaSvpPython $projectRoot
    $audioArgs = @((Join-Path $projectRoot 'tools/audio/mdsdrv-bank.py'))
    if ($MusicManifest) { $audioArgs += @('--music-manifest', $MusicManifest) }
    & $releasePython @audioArgs
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la preparacion MDSDRV de la ROM oficial.' }
}
$listingPath = Join-Path $buildDir "$Target.lst"
$logPath = Join-Path $buildDir "$Target-assembler.log"
if (Test-Path -LiteralPath $listingPath) { Remove-Item -LiteralPath $listingPath }
Push-Location $sourceDir
try {
    $output = & $Asm68k /p "$entry,$pendingPath,,$listingPath" 2>&1
    $assemblerExitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath $logPath -Encoding UTF8
    $output | ForEach-Object { Write-Host $_ }
    if ($assemblerExitCode -ne 0 -or -not (Test-Path -LiteralPath $pendingPath)) {
        throw "asm68k fallo (exit $assemblerExitCode). Consulte $logPath."
    }
    $rom = [IO.File]::ReadAllBytes($pendingPath)
    if ($rom.Length -ne 0x400000) { throw "Tamano ROM inesperado: $($rom.Length)." }
    if ($rom[0x1c8] -ne 0x53 -or $rom[0x1c9] -ne 0x56) { throw 'Falta firma SVP en $1c8.' }
    if ($rom[0x800] -ne 0x4c -or $rom[0x801] -ne 0x00) { throw 'Falta salto de entrada DSP en $800.' }
    if ([Text.Encoding]::ASCII.GetString($rom, 0x810, 4) -ne 'OHMP') { throw 'Falta firma de deteccion SVP en $810.' }
    if ($rom[4] -ne 0 -or $rom[5] -ne 2 -or $rom[6] -ne 0 -or $rom[7] -ne 0) {
        throw 'Vector de reset 68000 inesperado (debe ser $20000).'
    }
    $checksum = 0
    for ($offset = 0x200; $offset -lt $rom.Length; $offset += 2) {
        $checksum = ($checksum + ([int]$rom[$offset] * 256) + $rom[$offset + 1]) -band 0xffff
    }
    $rom[0x18e] = [byte]($checksum -shr 8)
    $rom[0x18f] = [byte]($checksum -band 0xff)
    [IO.File]::WriteAllBytes($pendingPath, $rom)
    if ($Target -eq 'm4-intro') {
        $releasePython = Resolve-MegaSvpPython $projectRoot
        # The same sources without graphics117: SSP code copied or overridden
        # in src/release/ must still match the generated program.
        $checkDir = Join-Path $buildDir 'g117-check'
        New-Item -ItemType Directory -Path $checkDir -Force | Out-Null
        $baseRom = Join-Path $checkDir 'base.bin'
        $baseListing = Join-Path $checkDir 'base.lst'
        $baseOutput = & $Asm68k /p /e M4_NO_GRAPHICS117=1 "$entry,$baseRom,,$baseListing" 2>&1
        if ($LASTEXITCODE -ne 0) { $baseOutput | ForEach-Object { Write-Host $_ }; throw 'asm68k fallo con la base sin graphics117.' }
        & $releasePython (Join-Path $projectRoot 'tools/check-g117-copies.py') $pendingPath $listingPath $baseRom $baseListing
        if ($LASTEXITCODE -ne 0) { throw 'El codigo SSP de src/release/ ya no coincide con el programa generado.' }
        & $releasePython (Join-Path $projectRoot 'tools/build-release.py') $pendingPath $listingPath --audio-engine mdsdrv
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la integracion de la ROM principal.' }
        $rom = [IO.File]::ReadAllBytes($pendingPath)
        $checksum = ([int]$rom[0x18e] * 256) + $rom[0x18f]
    }
    Test-MegaSvpGenplusIdle $rom $listingPath
    Move-Item -LiteralPath $pendingPath -Destination $romPath
    # Include the prebuilt Z80 binary and its reproducible MIT sources.
    $sourceHashes = [ordered]@{}
    foreach ($source in Get-ChildItem -LiteralPath $sourceDir -File -Recurse | Where-Object Extension -In '.asm','.bin','.s80','.i80','.inc','.json' | Sort-Object FullName) {
        $rel = [IO.Path]::GetRelativePath($sourceDir, $source.FullName).Replace('\', '/')
        $sourceHashes[$rel] = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
    }
    [ordered]@{
        built_utc = [DateTime]::UtcNow.ToString('o')
        rom = "build/$romName"
        target = $Target
        entry = "src/$entry"
        bitmap_layout = 'vr-paired'
        audio_engine = $(if ($Target -eq 'm4-intro') { 'mdsdrv' } else { 'diagnostic' })
        bytes = $rom.Length
        sha256 = (Get-FileHash -LiteralPath $romPath -Algorithm SHA256).Hash
        checksum = ('{0:X4}' -f $checksum)
        assembler = $Asm68k
        assembler_sha256 = (Get-FileHash -LiteralPath $Asm68k -Algorithm SHA256).Hash
        assembler_banner = ($output | Select-Object -First 4) -join "`n"
        extraction = $stamp
        sources = $sourceHashes
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    if ($Target -eq 'm4-intro') {
        $integration = Get-Content -LiteralPath (Join-Path $buildDir 'mdsdrv/release-integration.json') -Raw | ConvertFrom-Json
        if (-not $integration.audio_complete) {
            Write-Warning 'Catalogo de audio sin integrar; consulte build/mdsdrv/release-integration.json.'
        }
    }
    Write-Host "ROM nueva: $romPath"
} catch {
    foreach ($file in @($romPath, $manifestPath, $pendingPath)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
    throw
} finally {
    Pop-Location
}
} finally {
    $env:MEGASVP_ASM68K = $previousAssembler
    $buildMutex.ReleaseMutex()
    $buildMutex.Dispose()
}
