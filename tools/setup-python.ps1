# Creates the project Python environment .venv (Python 3.10+ with the packages of
# tools/requirements-extract.txt: Pillow and NumPy) used by extract_sf.ps1.
# Base interpreter: -Python <path>, else the py launcher (py -3), else python on PATH.
param([string]$Python = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Python) {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) { $Python = (& $py.Source -3 -c 'import sys; print(sys.executable)').Trim() }
    else {
        $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($cmd) { $Python = $cmd.Source }
    }
}
if (-not $Python -or -not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw 'No se encontro Python 3. Instalelo (py launcher o PATH) o use -Python <ruta>.'
}
& $Python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'
if ($LASTEXITCODE -ne 0) { throw "Se necesita Python 3.10 o posterior: $Python" }
$venv = Join-Path $root '.venv'
& $Python -m venv $venv
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear .venv.' }
$venvPython = Join-Path $venv 'Scripts\python.exe'
& $venvPython -m pip install -r (Join-Path $PSScriptRoot 'requirements-extract.txt')
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar las dependencias de extraccion.' }
& $venvPython -c 'import PIL, numpy; print("Pillow", PIL.__version__, "NumPy", numpy.__version__)'
Write-Host "Entorno listo: $venvPython"
