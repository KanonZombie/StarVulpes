# Atribuciones

- **SVP Development Tools**, Javier de Silóniz Sandino. Fuente de píxeles,
  tabla ASCII y ejemplos de inicialización SVP. Aviso MIT en
  `licenses/svpdev-MIT.txt`. [Proyecto original](https://github.com/jdesiloniz/svpdev)
- **SGDK 2.11**, Stéphane Dallongeville. Driver XGM2 de diagnóstico, fuentes
  Z80 adaptadas y binario correspondiente. Aviso MIT en
  `licenses/sgdk-MIT.txt`. [Proyecto original](https://github.com/Stephane-D/SGDK/tree/v2.11/src/snd/xgm2)
- **MDSDRV 0.6**, Ian Karlsson. La compilación usa una copia local del
  driver, con adaptaciones 68000/Z80 generadas en `build/`. Aviso zlib en
  `licenses/mdsdrv-zlib.txt`. `mdslink` pertenece a ctrmml.
  El empaquetado de gráficos usa Salvador y el decodificador ZX0 de
  Emmanuel Marty, reescrito por ctr, incluidos en el paquete local.
  [MDSDRV](https://github.com/superctr/MDSDRV), [ctrmml](https://github.com/superctr/ctrmml)
- **Snes9x/bapu**, S-SMP por byuu (2016), y demás autores del aviso Snes9x.
  El extractor offline `spc-trace.exe` incluye su intérprete SMP sin modificar
  para ejecutar el controlador SPC extraído localmente. Se distribuye para
  uso no comercial con el aviso completo en `licenses/snes9x-noncommercial.txt`.
  La [release del extractor](https://github.com/KanonZombie/StarVulpes/releases/tag/spc-trace-v1.0.0)
  incluye las fuentes exactas usadas, hashes y licencia. Proceden de
  [Emu EX Plus Alpha](https://github.com/Rakashazi/emu-ex-plus-alpha).
  Se excluye `iplrom.cpp`; nuestro adaptador usa un IPL vacío y rechaza su
  ejecución. El extractor no contiene recursos de Star Fox y no se incorpora
  al cartucho. [Procedimiento](tools/audio/SPC_TRACE.md).

Star Fox se usa como referencia de ingeniería y como entrada local del
extractor. Los recursos del juego pertenecen a sus titulares. Los avisos
anteriores corresponden al código de terceros indicado en cada punto.
