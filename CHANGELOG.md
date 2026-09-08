# Registro de cambios

Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [0.2.2] — 2026-09-07

### Gesto y precisión

- Reconoce sacudidas horizontales, verticales y diagonales mediante inversiones vectoriales rápidas, sin favorecer un eje.
- Exige que macOS haya publicado contenido importable nuevo en el portapapeles de arrastre durante la pulsación actual antes de mostrar la bandeja.
- Evita abrir MiniTray al seleccionar texto o mover contenido interno en aplicaciones como Canva cuando no existe un arrastre real de archivo o imagen.
- Conserva los umbrales configurables de sensibilidad, distancia, velocidad, número de inversiones y enfriamiento.

### Apariencia

- Retira las instrucciones visibles de uso de la bandeja vacía y conserva únicamente una señal gráfica discreta y accesible.

### Pruebas

- Añade cobertura para sacudidas verticales y diagonales, trayectorias curvas normales, datos antiguos del portapapeles, contenido no importable y un arrastre fresco válido.

## [0.2.1] — 2026-09-07

### Identidad

- Adopta **MiniTray** como nombre definitivo de la aplicación, del proyecto de Xcode, del ejecutable y de los targets de pruebas.
- Integra el logotipo aprobado como icono nativo de macOS en todas las resoluciones Retina requeridas.
- Mantiene una adaptación monocromática y legible del símbolo de bandeja en la barra de menús, donde el logotipo completo perdería claridad por su tamaño.
- Conserva el identificador interno de la versión anterior para mantener las preferencias y permisos locales durante la transición.

### Pruebas y distribución

- Evita ejecuciones paralelas del test host de barra de menús para impedir conflictos entre varias instancias de Launch Services.
- Actualiza los scripts, el esquema, la documentación y los artefactos de distribución al nombre MiniTray.

## [0.2.0] — 2026-09-07

### Interacción y apariencia

- Reduce la bandeja compacta a 236 × 236 puntos y la vista detallada a 480 puntos de ancho, con miniaturas, espacios y controles reajustados.
- Deja únicamente el logotipo de bandeja en la barra de menús, sin el título textual permanente.
- Añade transiciones breves para aparición, depósito, expansión, contracción, cancelación y cierre, respetando **Reducir movimiento**.
- Atenúa los controles secundarios mientras se arrastran elementos hacia otra aplicación y los restaura si la operación se cancela.
- Eleva temporalmente la bandeja durante un arrastre externo para que permanezca disponible sobre Finder y paneles modales, y recupera después el nivel flotante normal.
- Mantiene el marco real y las zonas de clic sincronizados durante todas las transiciones; ninguna animación redimensiona la ventana.

### Pruebas

- Añade cobertura para el estado de salida/restauración, las duraciones con movimiento reducido y la política de superposición.
- Verifica visualmente la bandeja compacta, el ciclo compacto → detalle → compacto, el movimiento manual y el cierre al primer clic con otra aplicación activa.

## [0.1.8] — 2026-09-07

### Apariencia

- Elimina el borde blanco translúcido que producía un contorno gris claro alrededor de la bandeja.
- Conserva el borde de acento únicamente durante la recepción de un arrastre, cuando funciona como confirmación visual.

## [0.1.7] — 2026-09-07

### Correcciones

- Sincroniza explícitamente la vista SwiftUI con el tamaño del panel para que un solo clic en la cápsula muestre todos los elementos.
- Hace que **Atrás** restaure siempre la pila compacta original, sin dejar una cuadrícula comprimida, recortada o aparentemente bloqueada.
- Añade una prueba de regresión que repite dos veces el ciclo de expansión y contracción y comprueba tanto el contenido dibujado como las dimensiones reales de la ventana.

## [0.1.6] — 2026-09-07

### Correcciones

- Muestra la imagen completa en la tarjeta compacta con ajuste proporcional, sin ampliarla ni recortar sus bordes.
- Convierte la previsualización central compacta en un destino real para archivos, carpetas e imágenes, además de conservar su función de arrastre de salida.
- Permite depositar nuevos elementos directamente sobre la cuadrícula cuando la bandeja está desplegada.
- Añade pruebas de geometría para imágenes verticales y horizontales y de los tipos aceptados por la zona central.

## [0.1.5] — 2026-09-07

### Correcciones

- Impide que la vista compacta conserve una ventana transparente de 520 puntos después de cerrar la cuadrícula expandida.
- Sincroniza de forma inmediata el tamaño visible, el tamaño de WindowServer y las zonas que reciben clics.
- Permite que el panel flotante sin bordes reciba el primer clic sin convertirlo en ventana principal ni activar innecesariamente la aplicación.
- Evita animaciones de redimensionado interrumpibles que podían dejar la X, la cápsula y la zona de movimiento fuera de sus posiciones interactivas reales.
- Conserva el tamaño visual intrínseco de SwiftUI sin permitir que sus mínimos transitorios vuelvan a ensanchar la ventana.

## [0.1.4] — 2026-09-07

### Correcciones

- Evita que el detector global procese los clics y movimientos que empiezan dentro de la propia bandeja.
- Hace que el área de movimiento y los controles respondan al primer clic aunque otra aplicación esté activa.
- Elimina una transición asíncrona que podía dejar el panel en un estado visual o interactivo incoherente.
- Restaura explícitamente la recepción de eventos del ratón cada vez que la bandeja se muestra.
- Impide que el clic de **Mostrar bandeja** se confunda con el final de un arrastre y la oculte inmediatamente.
- Añade una prueba automatizada para impedir regresiones de la interacción interna.

## [0.1.3] — 2026-09-07

### Mejoras

- Añade el interruptor **Abrir MiniTray al iniciar sesión** en Ajustes.
- Registra o elimina la aplicación principal mediante la API nativa `SMAppService`.
- Refleja el estado real configurado en macOS y muestra cuándo hace falta aprobación en Ítems de inicio.
- Permite activar el servicio aunque macOS todavía no lo haya visto y devuelva el estado inicial `notFound`.
- Incluye dos pruebas automatizadas para activación, desactivación y estados del sistema.

## [0.1.2] — 2026-09-07

### Mejoras

- Añade una solicitud explícita de Monitorización de entrada para la detección global fiable del gesto.
- Usa un monitor pasivo de Core Graphics limitado al botón izquierdo y excluye eventos de teclado.
- Muestra el estado del permiso y una acción para concederlo en la barra de menús y en Ajustes.
- Cambia automáticamente al modo protegido cuando macOS concede el permiso y conserva un modo limitado si se deniega.
- Añade una prueba de privacidad para comprobar la máscara exacta de eventos observados.

## [0.1.1] — 2026-09-07

### Correcciones

- Mantiene visible el acceso de MiniTray en la barra de menús.
- Corrige la aparición inmediata del panel durante un arrastre externo.
- Reduce falsos positivos con muestreo continuo del botón y el cursor.

## [0.1.0] — 2026-09-07

Primera versión pública del MVP.

### Incluye

- MiniTray flotante única para archivos, carpetas e imágenes.
- Activación mediante sacudida durante un arrastre.
- Vista compacta apilada y cuadrícula expandida.
- Miniaturas nativas mediante Quick Look.
- Drag & drop de entrada y salida con referencias temporales.
- Acciones nativas: Abrir con, Finder, Vista rápida, AirDrop, Mail y Mensajes.
- Liquid Glass en macOS 26 y material compatible en macOS 14–15.
- Ajustes de sensibilidad, atajo global, capturas de pantalla y doble clic.
- 23 pruebas automatizadas de la lógica aislable.

### Limitaciones

- Aplicación sin notarizar y con firma ad hoc.
- Algunos flujos entre aplicaciones requieren validación manual en Finder.
- No incluye historial, nube, cuentas ni persistencia de la bandeja.

[0.1.0]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.0
[0.1.1]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.1
[0.1.2]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.2
[0.1.3]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.3
[0.1.4]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.4
[0.1.5]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.5
[0.1.6]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.6
[0.1.7]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.7
[0.1.8]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.1.8
[0.2.0]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.2.0
[0.2.1]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.2.1
[0.2.2]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.2.2
