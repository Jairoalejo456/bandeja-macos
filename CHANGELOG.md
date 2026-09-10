# Registro de cambios

Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [0.2.9] — 2026-09-09

### Miniaturas y señal de traslado

- Rasteriza la primera página del PDF sobre papel blanco opaco, conservando proporción, rotación y recorte, sin modificar el documento. Corrige también el escalado de páginas pequeñas en Retina.
- Realiza la lectura PDF en una cola de fondo y comparte la miniatura entre pila, cuadrícula y arrastre. Agrupa solicitudes simultáneas para evitar renderizados repetidos.
- Usa las previsualizaciones al arrastrar, tanto en la pila como en la cuadrícula, y las actualiza si terminan de cargar durante la sesión.
- Añade una flecha de 16 puntos al primer archivo del conjunto. Indica intención de traslado, no aceptación ni resultado del destino. El cursor nativo conserva la señal de copia/rechazo; Opción retira la flecha y las imágenes en memoria no la muestran.
- Mantiene intactas las URLs, las operaciones nativas de movimiento/copia, las promesas de imagen, el cierre y la cancelación. No añade permisos ni dependencias externas.

### Verificación

- 85 pruebas XCTest correctas: 12 casos nuevos para PDF opaco, rotación, recorte, escalado Retina, documentos inválidos, caché compartida, proporción/transparencia, asociación de URLs y señal con Opción; conserva las 73 pruebas anteriores.
- Revisión visual de un PDF sintético en pila y cuadrícula. Comparación del raster nativo con Poppler y revisión de la imagen de arrastre generada con y sin flecha. El documento de prueba mantiene exactamente su huella SHA-256.
- La automatización del ratón inicia la sesión AppKit, pero no entrega su finalización; por ello no se declara verificada en esta pasada la transferencia/cancelación real entre aplicaciones ni la señal durante todo el recorrido. Se retiró un ajuste provisional de recarga de celdas al comprobar este límite del control automático.
- Compilación Release universal (Apple Silicon e Intel), firma e instalación local 0.2.9 (19) verificadas con el mismo certificado e identificador. Respaldo recuperable de 0.2.8 y ninguna publicación remota en esta pasada. La lógica de mover archivos no se sustituye por operaciones propias del sistema de archivos; los destinos siguen negociando la operación nativa.

### Publicación acumulada

- Publica en GitHub la entrega 0.2.9, incluyendo los cambios de 0.2.7 y 0.2.8 que hasta esta pasada solo estaban disponibles localmente. Incluye fuente, pruebas, documentación, ZIP universal ad hoc, SHA-256 y licencia MIT.
- Repite las 85 pruebas y reconstruye Release desde una copia limpia del código publicable. Completa una revisión estática general de seguridad sin vulnerabilidades reportables; no equivale a auditar los frameworks de macOS ni todos los flujos externos.
- Precisa la documentación sobre traslado consentido, consulta de Opción y retención temporal de cachés de previsualización. Conserva explícitos los límites de verificación funcional.

## [0.2.8] — 2026-09-09

### Traslado de archivos

- Corrige la máscara de arrastre que restringía a copia tanto la pila compacta como la cuadrícula. Finder puede mover las URLs originales al destino.
- Unifica la política de salida y calcula la operación de la cuadrícula solo a partir de los elementos seleccionados. Mantiene las promesas de PNG para imágenes en memoria y los modificadores nativos de macOS.
- Recoger, cerrar o cancelar sigue sin tocar los originales. La notificación de salida solo descarta referencias: no hay borrado posterior ni una operación de archivos programada por MiniTray.

### Verificación

- 73 pruebas XCTest correctas. Añade casos para archivos/carpetas, imágenes en memoria, lotes mixtos, selección expandida, cancelación/cierre y protección de un archivo nuevo que aparezca en la antigua ruta tras un traslado.
- Prueba manual asistida con Finder: PDF individual desde la cuadrícula y pila compacta de dos PDF y una carpeta. Los cuatro originales desaparecen del origen y las huellas SHA-256 de destino coinciden exactamente.
- La prueba automática del ratón no completó los arrastres; el usuario los ejecutó y la comprobación de ubicaciones y huellas se realizó por separado. No se afirma haber probado un volumen externo ni envíos reales a otras aplicaciones.
- Cierre con X comprobado en la copia de prueba: el archivo mantuvo su huella. La repetición de un arrastre hacia la misma carpeta no pudo verificarse automáticamente y permanece en la lista de comprobaciones manuales.
- Compilación Release universal (Apple Silicon e Intel), firma verificada e instalación local con el mismo identificador y certificado que la versión anterior. Se conserva un respaldo local de 0.2.7. No se publica una nueva versión en GitHub en esta pasada.

## [0.2.7] — 2026-09-09

### Movimiento nativo

- Adapta la referencia de movimiento entregada para entrada, recepción, absorción de carpeta, expansión/colapso, salida y compartición.
- Evalúa las curvas Bézier y sus fotogramas clave con un único reloj cancelable que se detiene cuando no hay animaciones.
- Redimensiona el panel real desde su posición actual, con fundido de contenido e inversión inmediata sin zonas de clic desajustadas.
- Conserva la presentación durante la salida sin retrasar el descarte lógico de referencias ni tocar los originales.
- Desactiva la animación de destino de AppKit antes de aceptar el depósito, para evitar una segunda animación de absorción.
- Anima la compartición cuando el servicio nativo confirma el envío. Cancelar o fallar no vacía la bandeja; un resultado atrasado tampoco descarta archivos nuevos.
- Respeta Reducir movimiento con fundidos de 120 ms y mantiene el vidrio recortado; no desenfoca el material de fondo.
- Evita recargar miniaturas y consultar tamaños de archivo en cada fotograma.

### Verificación

- 67 pruebas XCTest correctas, incluyendo curvas, secuencias, interrupciones, cierre/reapertura, absorción cancelada y 50 inversiones de tamaño con 32 elementos.
- Verifica la misma ruta de confirmación para AirDrop, Mail, Mensajes y servicios genéricos de terceros desde «Más opciones…», sin realizar envíos reales. Documenta la diferencia entre compartir mediante un servicio nativo y «Abrir con», que no comunica un envío posterior.
- Comprobación interactiva de pila, expansión/regreso con un clic, cabecera, menú nativo y cancelación de AirDrop.
- Los límites de la comprobación entre aplicaciones están documentados en [Motion-0.2.7](Docs/Motion-0.2.7.md); no se declara una transferencia AirDrop real ni equivalencia píxel a píxel.

## [0.2.6] — 2026-09-08

### Publicación bajo MIT

- Publica el proyecto bajo la licencia MIT, con atribución a Jairoalejo456 y a los colaboradores de MiniTray.
- Incluye la licencia en el repositorio y en los recursos de la aplicación para conservarla al distribuir el binario.
- Actualiza las instrucciones de descarga, requisitos de compilación y condiciones de contribución.
- Añade una huella SHA-256 al paquete publicado para verificar la integridad de la descarga.
- Mantiene las funciones y las correcciones auditadas en 0.2.5. No introduce cambios en la lógica de la aplicación.

## [0.2.5] — 2026-09-08

### Correcciones de la auditoría final

- Detecta una captura creada justo después de arrancar el monitor, incluso si Spotlight la entrega dentro de su recopilación inicial, sin confundir capturas antiguas con nuevas.
- Permite iniciar al primer intento un arrastre desde cualquier parte de una celda de la cuadrícula expandida aunque Finder u otra aplicación tenga el foco.
- Conserva la salida mediante promesa de archivo para imágenes que solo existen en memoria y verifica que los datos escritos sean idénticos al original.

### Verificación

- Ejecuta 46 pruebas XCTest sin fallos y el análisis estático de Release sin advertencias funcionales.
- Comprueba con arrastres reales Finder → MiniTray → Finder los gestos horizontal, vertical y diagonal, el depósito central, la pila múltiple, la cuadrícula, el movimiento, la cancelación y el cierre automático.
- Abre y cancela los flujos nativos de Quick Look y AirDrop conservando el contenido.
- Verifica el atajo global, el doble clic configurable y la detección temporal de una captura real.

## [0.2.4] — 2026-09-08

### Apariencia

- Recorta la composición completa de Liquid Glass al contorno redondeado de la bandeja.
- Elimina la sombra de SwiftUI que se rasterizaba como un rectángulo oscuro alrededor de la ventana transparente.
- Centra visualmente el icono de bandeja vacía respecto de toda la superficie, compensando el espacio ocupado por la cabecera.
- Conserva el vidrio nativo, el tinte carbón y los controles circulares sin recuperar bordes o fondos cuadrados.

## [0.2.3] — 2026-09-08

### Liquid Glass

- Reduce el tinte opaco de la superficie para que el Liquid Glass nativo vuelva a reflejar el color y la luz del contenido situado detrás.
- Refuerza la profundidad con una iluminación diagonal sutil sin recuperar el contorno gris retirado anteriormente.
- Mantiene archivos, miniaturas y controles a opacidad completa durante el arrastre; la interacción ya no manda partes de la bandeja visualmente a segundo plano.

### Ventana

- Mantiene el panel en un nivel elevado constante mientras está visible, incluso cuando Finder u otra aplicación recibe el foco.
- Conserva el comportamiento no activante para no interrumpir el trabajo en la aplicación de destino.

### Pruebas

- Actualiza la prueba de nivel de ventana para exigir la misma elevación antes, durante y después de un arrastre externo.

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
[0.2.9]: https://github.com/Jairoalejo456/minitray-macos/releases/tag/v0.2.9
