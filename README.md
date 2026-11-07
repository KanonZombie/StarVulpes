# StarVulpes

Port experimental a Sega Mega Drive/Genesis con SVP. La compilación local
extrae y convierte los recursos de un volcado de Star Fox para SNES.

*Vulpes* alude al zorro y **S**tar**V**ul**P**es es un guiño al chip SVP.

## Compilar en Windows

1. Coloca el volcado **Star Fox (USA), revisión 0**, de 1.048.576 bytes y sin
   cabecera de copiador, en `ref/Star Fox (USA).sfc`. El build exige SHA-256
   `3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d`.
2. En Windows x64, instala PowerShell 7.2 o posterior y Python 3.14.
   Ejecuta `./tools/setup-python.ps1` desde PowerShell 7 para crear `.venv`.
   No se necesita instalar Visual Studio ni descargar fuentes de Snes9x.
3. Configura las herramientas locales mediante variables de entorno o copiando
   `megasvp.local.example.json` a `megasvp.local.json`.

   | Variable | Entrada |
   | --- | --- |
   | `MEGASVP_ASM68K` | Ruta de SN 68k `asm68k.exe` 2.53 |
   | `MEGASVP_FFMPEG` | FFmpeg con el demuxer `libgme` |
   | `MEGASVP_MDSDRV` | Directorio MDSDRV 0.6 con `src/` y `tools/` (`mdslink.exe`, `sjasmplus.exe`, `salvador.exe`) |

   Herramientas de audio y compresión:
   [MDSDRV](https://github.com/superctr/MDSDRV).

4. Ejecuta `./rebuild.ps1`. Desde Windows PowerShell 5.1, el script se
   relanza automáticamente con PowerShell 7. La ROM de 2 MiB se genera en
   `build/StarVulpes.bin`. Usa un emulador compatible con SVP.

La compilación usa un directorio temporal para la extracción y el
ensamblado. Su única salida en `build/` es `StarVulpes.bin`.
Con `./rebuild.ps1 -KeepIntermediates` se conservan los recursos, listados e
informes de diagnóstico.

El extractor SPC para Windows x64 está incluido en el checkout como
`tools/audio/spc-trace.exe`. La extracción verifica su SHA-256 antes de
usarlo; no descarga herramientas. Sus fuentes y atribuciones también están
incluidas. El ejecutable incorpora el intérprete SMP y el runtime de C++;
no incluye datos de Star Fox ni la ROM de arranque IPL.
[Versión, verificación y reconstrucción opcional](tools/audio/SPC_TRACE.md).

El build convierte 52 secuencias musicales desde el SPC de la ROM, con
temas de las etapas, jefes y créditos. Recupera las notas, la duración y
los puntos de retorno del original. Usa timbres FM/PSG adaptados y
percusión extraída del BRR original.

## Editar los datos extraídos

`./extract_sf.ps1` lee el volcado y escribe los recursos en `build/`.
Las tablas `.inc` son texto de ensamblador editable, con direcciones de
origen. `build/m4-andross-panels.inc` contiene posiciones y tiempos,
`build/m4-flight-space.inc` los límites de vuelo en el espacio,
`build/m4-route-parameters.inc` los valores de inicio y cambios de ruta y
`build/m4-title-parameters.inc` los ángulos y tiempos del título.
`build/m4-weapon-sounds.inc` contiene los sonidos por arma,
`build/m4-arrow-masks.inc` y `build/m4-arrow-bits.inc` las máscaras del HUD,
y `build/level-result-faces.inc` los selectores de retratos de resultados.
`build/level-hud.json` contiene las alturas, márgenes, colores y paleta de
las barras de escudo, boost y jefe. `build.ps1` regenera sus tiles y vuelve
a empaquetar los gráficos a partir de los archivos extraídos. Escudo y
boost comparten el ancho, el margen horizontal y el color del marco.
`build/audio-native/music-commands.json` permite editar los comandos
musicales por dirección de origen. Durante la extracción, los decodificadores
leen sus patrones de scripts y firmas de comprobación del volcado.

El flujo también genera recursos en formato binario para la consola,
como tiles, mapas comprimidos y muestras PCM. Algunas herramientas de
diagnóstico exportan imágenes PNG para inspección.
`build/extraction-references.json` documenta las referencias binarias de
esta extracción como hexadecimal con direcciones de origen. Los JSON de
fondos describen los valores decodificados y los recursos convertidos.

Después de retocar esos archivos, ejecuta `./build.ps1`. El ensamblado
reutiliza la extracción vigente y puede ejecutarse con el volcado apartado.
`./rebuild.ps1` vuelve a extraer del volcado y compila en ese orden.

## Cambiar la música

Pon tus archivos en `music/local/` y compila con `-MusicManifest` para
reemplazar temas con tus MML de ctrmml. La carpeta local queda fuera del
historial. [Guía de música, formato y catálogo](music/README.md)

El volcado original, la ROM generada y los recursos extraídos se mantienen
fuera del historial. Las atribuciones de las herramientas y el código
reutilizado figuran en [THIRD_PARTY.md](THIRD_PARTY.md).
