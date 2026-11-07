# Extractor SPC offline

`tools/audio/spc-trace.exe` está versionado en el repositorio y queda
disponible con el checkout. La extracción usa directamente ese archivo
para Windows x64: no descarga herramientas ni necesita Visual Studio,
Visual C++ Redistributable o una instalación de Snes9x.

`ensure-spc-trace.ps1` y `trace-score.py` comprueban su SHA-256 contra
`spc-trace.json` antes de usarlo. Si falta o está alterado, la extracción
falla; restaura el archivo desde Git. No hay descarga ni compilación
automática como alternativa. En el build limpio se copia con `tools/` al
directorio temporal; el original permanece en el checkout y en `build/`
solo queda `StarVulpes.bin`.

La herramienta ejecuta el driver SPC obtenido del volcado local y registra
eventos, tiempos y bucles. Contiene nuestro adaptador y el intérprete SMP
de Snes9x/bapu; no contiene el driver original, música, muestras ni ROM
de arranque IPL. El IPL se sustituye por ceros y se rechaza su ejecución.
El intérprete SPC no se incorpora al cartucho Mega Drive.

## Fuentes, licencia y reconstrucción opcional

El checkout contiene el adaptador `spc-trace.cpp`, las diez unidades SMP
necesarias en `snes9x-smp/` y su procedencia y hashes en
`snes9x-smp/provenance.json`. Las unidades SMP coinciden con Emu EX Plus
Alpha, commit `3abb3985c85cbff3530a9ea7f1d0e21458f2d32a`. Se excluyen
`iplrom.cpp` y el resto del emulador. S-SMP es obra de byuu (2016).

El extractor derivado y su adaptador se distribuyen para uso no comercial
bajo el aviso completo de Snes9x en `licenses/snes9x-noncommercial.txt`.
Esas condiciones no conceden derechos sobre los datos del juego.

Solo para reconstruir esta herramienta se necesitan Visual Studio C++
Build Tools x64 y PowerShell. Desde la raíz del repo:

```powershell
./tools/audio/build-spc-trace.ps1
```

El script usa las fuentes SMP incluidas y escribe un nuevo ejecutable en
`build/audio-native/spc-trace.exe`; no reemplaza automáticamente el
versionado. También acepta `-Core <directorio-smp>` o `MEGASVP_SPC_CORE`
para desarrollo. Se compila con `/O2 /std:c++17 /EHsc /MT /Brepro` y
enlaza con `/Brepro`. El runtime es estático. La procedencia registra el
toolchain y hashes; no se garantiza igualdad entre versiones de MSVC.

Para adoptar un extractor modificado, copia el ejecutable a
`tools/audio/spc-trace.exe` y actualiza versión, SHA-256 y procedencia.
El hash del ejecutable identifica también las trazas cacheadas, que se
regeneran cuando cambia el convertidor. Publica juntos fuentes, binario,
manifiesto y avisos. No se necesitan releases para extraer ni compilar.
