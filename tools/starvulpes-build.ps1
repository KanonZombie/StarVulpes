# Build the public ROM in a disposable copy. The extractors and assembler
# use paths relative to the source tree, including the generated build/.
param([string]$RomName, [string]$Asm68k, [string]$MusicManifest)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = New-Item -ItemType Directory -Path (Join-Path $root 'build') -Force
if ($build.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'La carpeta build/ debe ser un directorio local para la compilacion limpia.'
}
$romPath = Join-Path $build.FullName $RomName
foreach ($file in $romPath, (Join-Path $build.FullName 'm4-intro-build.json')) {
    if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file -Force }
}

$sourceRom = Join-Path $root 'ref/Star Fox (USA).sfc'
if (-not (Test-Path -LiteralPath $sourceRom -PathType Leaf)) { throw "Falta la ROM de Star Fox: $sourceRom." }
$Asm68k = Resolve-MegaSvpAsm68k $root $Asm68k
if ($MusicManifest) { $MusicManifest = (Resolve-Path -LiteralPath $MusicManifest).Path }

# Resolve tools in the original checkout before changing the working directory.
$tools = @{
    MEGASVP_PYTHON = Resolve-MegaSvpPython $root
    MEGASVP_MDSDRV = $env:MEGASVP_MDSDRV
}
if (-not $tools.MEGASVP_MDSDRV) { $tools.MEGASVP_MDSDRV = Join-Path (Split-Path -Parent $root) 'MDSDRV' }
if ($env:MEGASVP_FFMPEG) { $tools.MEGASVP_FFMPEG = $env:MEGASVP_FFMPEG }

$previous = @{}
$stagePath = Join-Path $build.FullName ('.sv-' + [Guid]::NewGuid().ToString('N'))
$stage = New-Item -ItemType Directory -Path $stagePath
try {
    foreach ($key in $tools.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key)
        if (-not (Test-Path -LiteralPath $tools[$key])) { throw "Configure $key. No existe $($tools[$key])." }
        [Environment]::SetEnvironmentVariable($key, (Resolve-Path -LiteralPath $tools[$key]).Path)
    }
    foreach ($path in 'src','tools','extract_sf.ps1','build.ps1') {
        Copy-Item -LiteralPath (Join-Path $root $path) -Destination $stage.FullName -Recurse
    }
    New-Item -ItemType Directory -Path (Join-Path $stage.FullName 'ref') | Out-Null
    Copy-Item -LiteralPath $sourceRom -Destination (Join-Path $stage.FullName 'ref')

    Push-Location -LiteralPath $stage.FullName
    try {
        & ./extract_sf.ps1
        & ./build.ps1 -Asm68k $Asm68k -MusicManifest $MusicManifest
    } finally {
        Pop-Location
    }
    [IO.File]::Move((Join-Path $stage.FullName "build/$RomName"), $romPath)
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) }
    $owned = Get-Item -LiteralPath $stagePath
    if ($owned.FullName -ne $stage.FullName -or $owned.Parent.FullName -ne $build.FullName -or
        ($owned.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "La carpeta temporal del build cambio: $stagePath."
    }
    Remove-Item -LiteralPath $owned.FullName -Recurse -Force
}
Write-Host "ROM final: $romPath"
