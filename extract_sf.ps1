# Extraction stage: everything generated from the Star Fox ROM (ref/Star Fox (USA).sfc)
# into build/: data tables, converted graphics, map programs and the SSP1601 code
# generated from them (build/*.inc, build/agent-*/). The SSP code generators that do
# not read the ROM themselves consume these outputs and run here too, in dependency
# order. build.ps1 only assembles; rebuild.ps1 runs both stages.
# Writes build/extract-sf.json: the ROM hash and a hash of tools/**/*.py,
# checked by build.ps1 to refuse stale or missing generated data.
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = $PSScriptRoot
. (Join-Path $projectRoot 'tools/stage-common.ps1')
$buildMutex = Enter-MegaSvpBuildLock $projectRoot
try {
    $buildDir = Join-Path $projectRoot 'build'
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    $stampPath = Join-Path $buildDir 'extract-sf.json'
    # A failed or interrupted extraction must not leave a valid stamp behind.
    if (Test-Path -LiteralPath $stampPath) { Remove-Item -LiteralPath $stampPath -Force }
    $sfRom = Join-Path $projectRoot 'ref/Star Fox (USA).sfc'
    if (-not (Test-Path -LiteralPath $sfRom -PathType Leaf)) { throw "Falta la ROM de Star Fox: $sfRom." }
    $sfSha = (Get-FileHash -LiteralPath $sfRom -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sfSha -ne $MegaSvpStarFoxSha256) { throw "ROM de Star Fox inesperada (SHA-256 $sfSha; se esperaba $MegaSvpStarFoxSha256)." }
    $python = Resolve-MegaSvpPython $projectRoot
    Write-Host "Python: $python"
    function Invoke-Tool([string]$Script, [string[]]$Arguments = @()) {
        & $python (Join-Path $projectRoot "tools/$Script") @Arguments
        if ($LASTEXITCODE -ne 0) { throw "Fallo $Script. Extraccion incompleta." }
    }
    # Some research checks also write local reports here.
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'evidence') -Force | Out-Null
    foreach ($script in @('generate-vr-video-layout.py', 'extract-title-background.py', 'extract-corneria-background.py',
                          'extract-intro.py', 'recover-intro-script.py', 'recover-level-script.py', 'scramble-cadence.py',
                          'generate-map-programs.py')) { Invoke-Tool $script }
    Invoke-Tool 'convert-screen-bg.py' @('controls', 'gameover', 'routemap', 'pepper', 'space12', 'continue')
    foreach ($script in @('convert-level-backgrounds.py', 'extract-route-map.py', 'generate-routemap-data.py',
                          'generate-controls-obj.py', 'generate-continue-obj.py', 'generate-gameover-data.py',
                          'recover-intro-text.py')) { Invoke-Tool $script }
    foreach ($script in @('recover-intro-font.py','recover-intro-camera.py','recover-intro-trails.py','recover-intro-ships.py',
                          'recover-intro-model.py','recover-intro-matrix.py','check-intro-orientation.py','check-intro-span-walk.py',
                          'recover-intro-fire.py','recover-intro-weapons.py','recover-intro-effects.py','generate-svp-text.py',
                          'generate-intro-raster.py','generate-intro-raster-tests.py','generate-intro-geometry.py',
                          'generate-intro-faces.py','generate-intro-later-tests.py','generate-intro-boss-tests.py',
                          'recover-intro-boss-scene.py','recover-intro-particles.py','generate-svp-particles.py',
                          'generate-svp-sprites.py','generate-svp-texpoly.py','recover-intro-debris.py','recover-intro-zacos.py',
                          'generate-intro-colours.py','generate-svp-bsp.py','generate-svp-chain.py','generate-level-shapes.py','generate-level-hud.py','extract-level-paths.py',
                          'generate-level-tilt.py','generate-level-messages.py','generate-level-radio.py','generate-level-texts.py',
                          'generate-svp-sphere.py','generate-svp-stars.py','generate-level-gamepals.py',
                          'extract-intro-background.py','generate-svp-planar.py')) {
        $toolArgs = @('--vr-layout')
        if ($script -eq 'generate-intro-raster-tests.py') { $toolArgs = @('--height=192', '--vr-layout') }
        if ($script -eq 'generate-level-hud.py') { $toolArgs = @('--extract') }
        Invoke-Tool $script $toolArgs
    }
    # Scaled text of the level (msprint, ending and credits): font and SSP raster.
    foreach ($script in @('ending-resources.py', 'extract-ending-font.py', 'generate-svp-ending-text.py',
                          'extract-runtime-tables.py', 'extract-encounter-tables.py')) { Invoke-Tool $script }
    Invoke-Tool 'extract-sf-sfx.py'
    Invoke-Tool 'audio/render-sfx.py'  # full-band captures for MDSDRV: build.ps1 needs no FFmpeg
    # Inputs of the MDSDRV audio integration (build.ps1): original SPC score
    # traces (offline converter, MSVC) and the compact SFX set from sf-sfx.
    & (Join-Path $projectRoot 'tools/audio/build-spc-trace.ps1')
    foreach ($script in @('audio/trace-score.py', 'audio/compact-sfx.py', 'audio/music-events.py')) { Invoke-Tool $script }
    [ordered]@{
        extracted_utc = [DateTime]::UtcNow.ToString('o')
        starfox_rom = 'ref/Star Fox (USA).sfc'
        starfox_sha256 = $sfSha
        inputs_sha256 = Get-MegaSvpExtractionInputsHash $projectRoot
    } | ConvertTo-Json | Set-Content -LiteralPath $stampPath -Encoding UTF8
    Write-Host "Extraccion completa: $stampPath"
} finally {
    $buildMutex.ReleaseMutex()
    $buildMutex.Dispose()
}
