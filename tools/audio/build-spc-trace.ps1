# Optional developer build. Normal extraction uses tools/audio/spc-trace.exe.
param([string]$Core = $env:MEGASVP_SPC_CORE, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $core) {
    $core = Join-Path $PSScriptRoot 'snes9x-smp'
}
if (-not (Test-Path -LiteralPath (Join-Path $core 'smp.hpp') -PathType Leaf)) {
    throw 'Falta el núcleo SPC. Defina MEGASVP_SPC_CORE con el directorio bapu/smp de Snes9x.'
}
$env:MEGASVP_SPC_CORE = (Resolve-Path -LiteralPath $core).Path
$out = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $root 'build/audio-native' }
New-Item -ItemType Directory -Force $out | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Falta Visual Studio C++ Build Tools (vswhere).' }
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) { throw 'Falta el compilador C++ de Visual Studio.' }
$vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
$source = Join-Path $root 'tools/audio/spc-trace.cpp'
$binary = Join-Path $out 'spc-trace.exe'
$object = Join-Path $out 'spc-trace.obj'
if (Test-Path -LiteralPath $binary) { Remove-Item -LiteralPath $binary }
$batch = Join-Path $out 'compile.cmd'
@('@echo off', ('set "PATH=%PATH%;{0}"' -f (Split-Path -Parent $vswhere)), ('call "{0}" >nul' -f $vcvars), 'if errorlevel 1 exit /b 1',
  ('cl /nologo /O2 /std:c++17 /EHsc /MT /Brepro /I "%MEGASVP_SPC_CORE%" "{0}" /Fo:"{1}" /Fe:"{2}" /link /Brepro' -f $source,$object,$binary)) |
    Set-Content -LiteralPath $batch -Encoding ascii
& $env:ComSpec /d /c $batch
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $binary)) { throw 'Fallo el build del convertidor SPC offline.' }
