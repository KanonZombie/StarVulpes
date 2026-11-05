# StarVulpes

Port experimental a Sega Mega Drive/Genesis con SVP. La compilación local
extrae y convierte los recursos de un volcado de Star Fox para SNES.

*Vulpes* alude al zorro y **S**tar**V**ul**P**es es un guiño al chip SVP.

## Compilar en Windows

1. Coloca el volcado **Star Fox (USA), revisión 0**, de 1.048.576 bytes y sin
   cabecera de copiador, en `ref/Star Fox (USA).sfc`. El build exige SHA-256
   `3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d`.
2. Instala PowerShell 7.2 o posterior, Python 3.14 y Visual Studio C++ Build Tools con las
   herramientas x64. Ejecuta `./tools/setup-python.ps1` desde PowerShell 7.
3. Configura las herramientas locales mediante variables de entorno o copiando
   `megasvp.local.example.json` a `megasvp.local.json`.

   | Variable | Entrada |
   | --- | --- |
   | `MEGASVP_ASM68K` | Ruta de SN 68k `asm68k.exe` 2.53 |
   | `MEGASVP_FFMPEG` | FFmpeg con el demuxer `libgme` |
   | `MEGASVP_SPC_CORE` | Directorio `apu/bapu/smp` de Snes9x con `smp.hpp`, `core.cpp`, `algorithms.cpp`, `memory.cpp` y `timing.cpp` |
   | `MEGASVP_MDSDRV` | Directorio MDSDRV 0.6 con `src/` y `tools/` (`mdslink.exe`, `sjasmplus.exe`, `salvador.exe`) |

   La combinación comprobada usa el SMP de
   `Snes9x/src/snes9x/apu/bapu/smp` de Emu EX Plus Alpha y las herramientas
   de Windows de MDSDRV. [Emu EX Plus Alpha](https://github.com/Rakashazi/emu-ex-plus-alpha),
   [MDSDRV](https://github.com/superctr/MDSDRV)

4. Ejecuta `./rebuild.ps1`. La ROM de 2 MiB se genera en
   `build/megasvp-m4-intro.bin`. Usa un emulador compatible con SVP.

`./extract_sf.ps1` regenera los recursos. `./build.ps1` reutiliza la
extracción vigente para cambios en el ensamblador. Las salidas y los
informes locales se guardan en `build/` y `evidence/`.

La conversión musical usa eventos y muestras extraídos del SPC de la ROM.
Los timbres FM/PSG son aproximaciones para Mega Drive. El catálogo activo
abarca intro, título, Corneria, su jefe y su fanfarria de final de fase.

El volcado original, la ROM generada y los recursos extraídos se mantienen
fuera del historial. Las atribuciones de las herramientas y el código
reutilizado figuran en [THIRD_PARTY.md](THIRD_PARTY.md).
