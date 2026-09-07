# Bandeja para macOS

Bandeja es una utilidad nativa de barra de menús para reunir temporalmente archivos, carpetas e imágenes mientras se trabaja entre Finder y otras aplicaciones. Mantiene una sola bandeja flotante y guarda únicamente referencias en memoria: añadir o cerrar nunca mueve ni elimina los originales.

Versión actual: **0.1.1 (MVP)**.

## Requisitos

- macOS 14.0 o posterior.
- Xcode 16 o posterior recomendado. La compilación de entrega se verificó con Xcode 26.6 y Swift 6.3.3 en modo de lenguaje Swift 5.
- Un Mac con AirDrop disponible para comprobar el flujo de compartición real.

No hay dependencias de terceros, servidor, cuenta ni almacenamiento persistente.

## Abrir y usar

1. Abre `Bandeja.xcodeproj` en Xcode.
2. Selecciona el esquema **Bandeja** y el destino **My Mac**.
3. Pulsa **Run** (`⌘R`). La app aparece como **Bandeja** junto a un icono en la barra de menús; no ocupa espacio en el Dock. El gesto solo funciona mientras la app está abierta y ese acceso está presente.
4. Empieza a arrastrar uno o más elementos en Finder.
5. Sin soltar el botón, mueve el cursor horizontalmente de un lado a otro tres veces con rapidez. La bandeja aparecerá cerca del cursor y siempre dentro del área visible de la pantalla.
6. Suelta los elementos dentro. La bandeja permanece pequeña y enseña una previsualización principal con hasta dos tarjetas detrás para indicar que hay más contenido.
7. Arrastra esa pila para sacar todos los elementos de una vez, o pulsa la cápsula de cantidad para abrir la cuadrícula y arrastrar uno o varios. Cuando otra aplicación acepta el arrastre, la bandeja se cierra automáticamente; si cancelas, conserva todo.

También se puede abrir una bandeja vacía desde el icono de barra de menús con **Mostrar bandeja**. Si no recibe nada, se oculta automáticamente; al terminar un arrastre sin depósito también se oculta. La sensibilidad del gesto puede cambiarse entre baja, equilibrada y alta desde ese menú, pero la configuración equilibrada funciona desde el primer inicio.

El menú de barra incluye **Ajustes…**. Allí se puede:

- cambiar la sensibilidad de la sacudida;
- activar un atajo global y elegir entre cuatro combinaciones para mostrar la bandeja;
- activar la detección de capturas guardadas por macOS y elegir entre 1 y 10 segundos de visibilidad;
- activar o desactivar que un doble clic sobre la previsualización o un elemento revele el archivo en Finder.

El atajo y la detección de capturas empiezan desactivados para evitar interferencias. Las preferencias sí se conservan entre aperturas; los elementos de la bandeja nunca se conservan.

La franja superior permite mover el panel. La vista compacta muestra únicamente la **X**, la pila y la cápsula de cantidad; no hay título, papelera ni acciones para quitar elementos. Cerrar con la **X** olvida todas las referencias y oculta la bandeja, pero nunca elimina los originales. La flecha superior abre un menú nativo con **Abrir con**, **Mostrar en Finder**, **Vista rápida** y los servicios de compartir que macOS tenga disponibles para esos elementos, incluidos AirDrop, Mail, Mensajes y otras extensiones instaladas. **Más opciones…** abre el selector completo del sistema.

En macOS 26 o posterior, la bandeja usa el material Liquid Glass real de SwiftUI, tintado en gris carbón y reservado a la superficie flotante y sus controles. En macOS 14 y 15 mantiene la misma jerarquía con materiales nativos translúcidos. Si está activado **Reducir transparencia**, emplea un fondo oscuro sólido de alto contraste.

Al pulsar la cápsula se abre una cuadrícula con todas las previsualizaciones y el tamaño total. El botón de regreso vuelve a la vista compacta sin perder contenido. La bandeja no crece al añadir más archivos mientras siga contraída; incluso con decenas de elementos conserva el mismo tamaño.

## Compilar y probar desde Terminal

Compilación Debug:

```bash
xcodebuild \
  -project Bandeja.xcodeproj \
  -scheme Bandeja \
  -configuration Debug \
  -derivedDataPath /tmp/BandejaDerivedData \
  build
```

Pruebas:

```bash
xcodebuild test \
  -project Bandeja.xcodeproj \
  -scheme Bandeja \
  -configuration Debug \
  -derivedDataPath /tmp/BandejaDerivedData \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO
```

Una compilación universal (Apple Silicon + Intel) lista para abrir queda en `dist/Bandeja.app` después del build Release usado para esta entrega. Tiene firma ad hoc local; no está notarizada ni firmada para distribución pública.

Para generar la aplicación y el ZIP de una versión local:

```bash
./scripts/build-release.sh
```

Las versiones publicadas y sus binarios se encuentran en [GitHub Releases](https://github.com/Jairoalejo456/bandeja-macos/releases).

## Arquitectura

- **SwiftUI** compone la presentación, el material, la jerarquía y los estados visuales.
- **Liquid Glass / materiales de AppKit** proporcionan profundidad y contexto sin sacrificar legibilidad: vidrio real en macOS 26, material translúcido de respaldo en macOS 14–15 y superficie sólida con Reducir transparencia.
- **NSPanel** proporciona una ventana flotante no activante, sobre ventanas normales y movible por su cabecera.
- **NSCollectionView / NSPasteboard** reciben URLs de archivo, carpetas e imágenes y publican de nuevo los elementos mediante drag & drop estándar. La pila compacta ofrece el conjunto completo; la cuadrícula permite una selección individual o múltiple. Los archivos existentes se ofrecen con URL y operación de copia; una imagen sin archivo de origen se conserva en memoria y se ofrece como PNG mediante `NSFilePromiseProvider` solo cuando el usuario la deposita fuera. Una salida aceptada descarta las referencias y cierra el panel; una salida cancelada no cambia el estado.
- **Quick Look Thumbnailing** solicita a macOS la miniatura nativa de cada URL. Imágenes, PDF, vídeo, documentos y otros formatos compatibles muestran su contenido; un tipo sin generador Quick Look usa como respaldo el icono nativo de Finder.
- **NSEvent** consulta de forma pasiva la posición global del cursor y el estado del botón izquierdo mientras la app está abierta. Este muestreo continúa durante arrastres pertenecientes a Finder u otras aplicaciones, sin instalar un event tap. El detector exige segmentos horizontales rápidos, distancia acumulada, tres inversiones de dirección, dominancia horizontal y un tiempo de enfriamiento. Solo hay un `NSPanel` y Launch Services prohíbe múltiples instancias de la app.
- **Carbon RegisterEventHotKey** registra opcionalmente el atajo global seleccionado sin inspeccionar pulsaciones y sin solicitar Accesibilidad.
- **Spotlight (`NSMetadataQuery`)** detecta opcionalmente capturas nuevas marcadas por macOS, descarta resultados anteriores y muestra una bandeja vacía durante el intervalo elegido. No copia la captura ni la añade automáticamente.
- **NSWorkspace, Quick Look y NSSharingService** construyen el menú de acciones con las aplicaciones y servicios que el sistema declara compatibles. AirDrop usa el flujo nativo y cancelar el selector conserva la bandeja.

## Permisos y privacidad

Bandeja no solicita Accesibilidad, Grabación de pantalla, Automatización ni acceso completo al disco. Consulta `NSEvent.mouseLocation` y `NSEvent.pressedMouseButtons`; no intercepta eventos ni observa el teclado. El atajo se registra como combinación concreta con el sistema y la detección de capturas consulta metadatos Spotlight de archivos, no el contenido de la pantalla.

Los archivos llegan únicamente porque el usuario los arrastra. El target no usa App Sandbox en este MVP para que las URLs explícitamente depositadas sigan siendo utilizables durante la sesión. No se sube información, no hay analítica y nada de la bandeja se restaura tras reiniciar.

En un Mac administrado, una política de seguridad podría impedir la entrega de eventos globales. En ese caso la app no debe considerarse capaz de detectar el gesto global; **Mostrar bandeja** en el icono de menú queda como alternativa comprensible.

## Limitaciones conocidas

- El contenido es deliberadamente efímero. Si el archivo original se mueve o borra desde otra aplicación, la referencia puede dejar de funcionar.
- AirDrop depende del hardware, de la configuración del sistema y de la disponibilidad de dispositivos cercanos.
- La detección de capturas solo puede reaccionar a archivos que macOS haya guardado e indexado como capturas. Una captura enviada únicamente al portapapeles no crea un archivo y no se detecta; Spotlight desactivado o una ubicación no indexada también pueden impedirla.
- El atajo global ofrece cuatro combinaciones predefinidas. Si otra aplicación ya usa la elegida, Ajustes muestra el conflicto y permite escoger otra.
- No hay historial, múltiples bandejas, sincronización, enlaces, compresión, extensiones de Finder, cuentas ni pagos.
- La app está construida para desarrollo local. Distribuirla fuera de Xcode requiere firma, notarización y los permisos de cuenta de Apple correspondientes, que no se realizaron.

La matriz de aceptación y los pasos de comprobación práctica están en [Docs/Manual-QA.md](Docs/Manual-QA.md). Las referencias y decisiones visuales están resumidas en [Docs/Visual-Research.md](Docs/Visual-Research.md).

## Contribuir y reportar problemas

Las mejoras y correcciones son bienvenidas mediante issues y pull requests. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar cambios y [SECURITY.md](SECURITY.md) para comunicar vulnerabilidades sin exponerlas públicamente.

## Licencia

Todavía no se ha elegido una licencia de código abierto. Mientras se toma esa decisión, el código se publica con los derechos reservados por sus autores. No se añadió una licencia irreversible sin autorización expresa del propietario.
