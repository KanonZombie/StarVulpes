# Extractor SPC offline

La extracción descarga `spc-trace.exe` para Windows x64 desde la release
[spc-trace-v1.0.0](https://github.com/KanonZombie/StarVulpes/releases/tag/spc-trace-v1.0.0).
La URL y el SHA-256 esperado están fijados en `spc-trace.json`. Tanto la
descarga como `trace-score.py` verifican el ejecutable antes de usarlo.
No se necesitan Visual Studio, Visual C++ Redistributable ni fuentes de
Snes9x para extraer o compilar el juego.

`ensure-spc-trace.ps1` conserva el ejecutable en `build/audio-native/` y
reutiliza esa copia solo si coincide su hash. Una descarga incompleta o
con hash incorrecto se descarta; un ejecutable existente incorrecto causa
un error y debe eliminarse antes de repetir. No hay compilación ni descarga
de otra versión como alternativa silenciosa. La primera descarga requiere
Internet; una copia previamente verificada permite extraer sin conexión.
En el build limpio, la herramienta vive en la copia temporal y se elimina
con los demás intermedios. La salida sigue siendo `build/StarVulpes.bin`.

La herramienta ejecuta el driver SPC obtenido del volcado local y registra
eventos, tiempos y bucles. El binario distribuido contiene nuestro adaptador
y el intérprete SMP de Snes9x/bapu; no contiene el driver original, música,
muestras ni ROM de arranque IPL. El IPL se sustituye por ceros y se rechaza
su ejecución. Ningún intérprete SPC se incorpora al cartucho Mega Drive.

## Reconstrucción opcional para desarrolladores

La misma release publica `spc-trace-v1.0.0-source.zip`, con el adaptador,
el script de compilación, las diez unidades SMP necesarias, su procedencia,
hashes y licencia. Se excluyen expresamente `iplrom.cpp` y el resto del
emulador. S-SMP fue escrito por byuu; se conservan los avisos completos de
Snes9x en `licenses/snes9x-noncommercial.txt`. Sus condiciones de uso no
comercial se aplican al extractor derivado, no a los datos del juego.

Solo para reconstruir esta herramienta se necesitan Visual Studio C++
Build Tools x64 y PowerShell. Descomprime las fuentes y ejecuta:

```powershell
./tools/audio/build-spc-trace.ps1
```

El script encuentra `snes9x-smp/` dentro del paquete y escribe
`build/audio-native/spc-trace.exe`. En el repo también acepta
`-Core <directorio-smp>` o `MEGASVP_SPC_CORE`, opcionales para desarrollo.
Se compila con `/O2 /std:c++17 /EHsc /MT /Brepro` y enlaza con `/Brepro`.
El runtime es estático. La release registra la versión del compilador y
los hashes de sus entradas; `/Brepro` no garantiza igualdad entre versiones
distintas de MSVC. Se comprobaron dos compilaciones idénticas con el mismo
toolchain.

Si modificas el extractor, actualiza el manifiesto local con la nueva
versión, URL y hash antes de extraer. El hash del ejecutable identifica
también las trazas cacheadas: se regeneran cuando cambia el convertidor.
Una publicación oficial debe usar una nueva release; no reemplazar el
binario de una versión publicada.
