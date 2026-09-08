# Verificación del MVP

Fecha de la pasada incluida: 7 de septiembre de 2026. Entorno: Mac Apple Silicon, macOS 26.6.2 (25G83), Xcode 26.6 (17F113), Swift 6.3.3.

## Resultado ejecutado

Las compilaciones Debug y Release y el análisis estático terminaron correctamente para esta actualización. La entrega Release es universal arm64/x86_64, tiene firma ad hoc local válida, exige macOS 14.0 o posterior y se abrió como proceso `.app` real (`com.jairo.bandeja`). La inspección de la versión anterior ya había confirmado:

- panel único y flotante, con estado vacío;
- visualización simultánea de una imagen JPEG, un PDF, un TXT y una carpeta;
- miniatura real de la imagen, primera página del PDF, vista previa del TXT e icono nativo de la carpeta;
- estado compacto de tamaño fijo con una previsualización principal, tarjetas posteriores y cápsula de cantidad;
- expansión a una cuadrícula con todos los nombres y regreso al tamaño compacto sin perder contenido;
- cabecera sin título ni basurero, con la X como único descarte visible;
- menú nativo expuesto a Accesibilidad con Abrir con, Mostrar en Finder, Vista rápida, AirDrop, Mail, Mensajes y los demás servicios disponibles;
- apertura real de Vista rápida con la primera imagen y navegación preparada para los tres elementos;
- presentación real del selector nativo de AirDrop con tres imágenes preparadas, cancelación sin envío y conservación de los tres elementos;
- arranque inicial con contenido vacío.

Esta actualización añade Liquid Glass nativo en macOS 26, respaldo de material en macOS 14–15, respeto de Reducir transparencia, Ajustes, atajo global opcional, detector opcional de capturas y doble clic configurable para revelar en Finder. La app nueva se inició como proceso real y permaneció estable. La herramienta de automatización detectó el proceso, pero cerró repetidamente su canal nativo al intentar adjuntarse a la superficie de Accesibilidad; por eso el acabado visual actualizado y los controles nuevos no se presentan como comprobados manualmente en esta pasada.

La versión 0.1.2 añade un monitor pasivo de Core Graphics y solicita Monitorización de entrada para detectar de forma fiable los arrastres que pertenecen a Finder u otra aplicación. La máscara automatizada se comprobó: incluye únicamente pulsación, arrastre y liberación del botón izquierdo, y excluye teclado y botón derecho. La concesión real del permiso depende de una decisión del usuario en macOS y queda pendiente de validación manual después de instalar esta compilación. La versión 0.1.3 incorpora además el inicio automático mediante el servicio nativo de macOS. Se activó en la aplicación instalada, macOS mostró el aviso nativo de elemento de inicio agregado y el estado continuó activo después de reiniciar la app; luego se desactivó y continuó apagado tras otro reinicio. La comprobación de un arranque de sesión completo sigue incluida en la lista manual.

Para la versión 0.1.4 se cerraron temporalmente Dropover y sus procesos auxiliares. Bandeja respondió durante 12 movimientos consecutivos; después se movió con una trayectoria horizontal de varias inversiones y terminó exactamente 100 × 100 puntos respecto a su posición inicial, demostrando que su propio gesto ya no reactiva el detector global. Con Finder activo, el botón de cierre respondió al primer clic y el archivo original permaneció intacto. Dropover quedó cerrado, no desinstalado.

Después de instalar la compilación final 0.1.4, Bandeja se añadió a **Privacidad y seguridad → Monitorización de entrada**, el interruptor quedó activo y macOS reinició la aplicación. Se ejecutó entonces una integración Finder → Bandeja con una imagen JPEG real: el botón izquierdo permaneció pulsado, se enviaron cinco inversiones horizontales rápidas y el panel apareció antes de soltar. La imagen se depositó en la bandeja y quedó expuesta como **1 imagen**. Con Finder nuevamente activo, la X cerró el panel al primer clic. La huella SHA-256 del original fue idéntica antes y después (`c444d824…c2fedb6`) y WindowServer confirmó cero paneles flotantes visibles después del cierre.

La versión 0.1.5 parte de una reproducción en vivo del segundo bloqueo informado. El proceso permanecía sano y la bandeja todavía aceptaba nuevos archivos, pero los clics físicos no llegaban a la X, la cápsula ni la zona de movimiento. WindowServer mostró la causa: aunque SwiftUI dibujaba la bandeja compacta de 264 puntos, `NSHostingView` conservaba el ancho mínimo de 520 puntos de la cuadrícula expandida. La corrección elimina esa restricción residual, sincroniza el marco sin animaciones interrumpibles y permite que el panel sin bordes reciba el primer clic sin convertirse en ventana principal.

Después de compilar e instalar la corrección final 0.1.5, se abrió la bandeja desde el menú con otra aplicación al frente. El panel vacío se renderizó correctamente con 264 × 180 puntos, nivel flotante 3 y fondo Liquid Glass visible. Un clic físico sobre la X cerró el panel al primer intento y WindowServer confirmó que no quedó ninguna ventana invisible. La primera variante de la corrección, que eliminaba todas las opciones de tamaño del alojamiento SwiftUI, se descartó durante esta comprobación porque también ocultaba el contenido; la versión final conserva solo el tamaño visual intrínseco y excluye los mínimos y máximos automáticos.

Para la versión 0.1.6 se reprodujo el recorte con la imagen vertical original de 1837 × 2281 píxeles. La nueva tarjeta compacta la dibujó completa, centrada y con su relación de aspecto intacta sobre el fondo neutro; también se comprobó visualmente una pila con dos elementos. El receptor central registra explícitamente URLs de archivo, PNG y TIFF, y la cuadrícula desplegada incorpora el mismo flujo de importación. La automatización de geometría y registro pasó, pero el depósito físico exactamente en el centro debe confirmarse también con un arrastre humano: el intento automatizado quedó interferido por Stage Manager y abrió la aplicación asociada al archivo en vez de producir un drag fiable.

Para la versión 0.1.7 se reprodujo el fallo de navegación con dos imágenes reales. WindowServer mostraba que el primer clic sí ampliaba el panel de 264 × 264 a 520 × 248 puntos, pero SwiftUI conservaba la jerarquía compacta anterior dentro del marco grande. La corrección reconstruye la raíz visual con el mismo estado que utiliza AppKit para dimensionar la ventana. En la comprobación práctica, un solo clic mostró ambas imágenes simultáneamente, **Atrás** restauró la pila de 264 × 264 y un segundo ciclo volvió a completar ambos cambios sin recortes ni bloqueo.

Para la versión 0.1.8 se retiró el trazo blanco translúcido de medio punto que rodeaba la superficie en reposo. La vista compacta se comprobó sobre un fondo claro, donde el contorno gris resultaba más visible: el panel conserva el vidrio oscuro, las esquinas redondeadas y la sombra de profundidad, pero ya no añade ese recuadro claro. El contorno de acento sigue apareciendo solamente al recibir un arrastre válido.

Para la versión 0.2.0 se redujo el panel compacto de 264 × 264 a 236 × 236 puntos y el detalle de 520 a 480 puntos de ancho. Con dos imágenes reales se comprobó visualmente la previsualización completa, una pulsación para abrir el detalle de 480 × 232, **Atrás** para recuperar exactamente 236 × 236 y la X para dejar cero ventanas visibles al primer clic. También se movió el panel mediante la cabecera de 900,551 a 442,237 sin perder el contenido ni desincronizar su marco. La barra de menús mostró únicamente el símbolo de bandeja, sin título. Durante la validación se descubrió y descartó una primera técnica de animación que interfería con la composición de Liquid Glass; la entrega usa cambios visuales temporizados dentro de SwiftUI y mantiene estático el marco real de AppKit. Dropover permaneció cerrado.

La corrección 0.1.1 también se comprobó contra WindowServer con el botón izquierdo mantenido y una trayectoria horizontal de tres inversiones: el gesto creó un único panel visible de 264 × 180 puntos, nivel flotante y opacidad 1 antes de soltar. Una trayectoria recta equivalente produjo cero ventanas, como se esperaba. Esta prueba recorre el muestreo global, el detector y la aparición real del `NSPanel`; no sustituye todavía el arrastre manual de un archivo desde Finder.

Se ejecutaron **38 pruebas XCTest, 38 correctas, 0 fallos**:

- 9 del detector: sacudida deliberada, arrastre normal, microtemblor, gesto lento, movimiento vertical dominante, reinicio al soltar, dos pruebas del muestreo global del botón y exclusión completa de los clics que empiezan dentro de la bandeja;
- 10 del estado: referencias sin modificación del original, varios archivos y carpetas, duplicados, entradas inválidas, imágenes en memoria, cierre al quedar vacío, expansión/contracción, salida cancelada, restauración visual y salida aceptada preservando el archivo real;
- 2 de `NSPasteboard`: varias URLs reales e imagen sin URL;
- 7 de ventana y movimiento: colocación en las cuatro esquinas y el centro del área visible, tamaño compacto idéntico con 1 o 32 elementos, capacidad del panel sin bordes para recibir el primer clic, ausencia de un tamaño mínimo residual impuesto por SwiftUI, sincronización repetida entre el estado visual y el marco, duraciones reducidas con **Reducir movimiento** y elevación temporal durante la recepción externa.
- 7 de configuración, privacidad e inicio: valores iniciales prudentes, persistencia independiente del contenido, filtro de capturas recientes, combinaciones distintas de atajos, máscara del monitor limitada al ratón y registro/desregistro del ítem de inicio con sus estados de aprobación.
- 3 de interacción compacta: ajuste completo de imágenes verticales y horizontales y registro de la zona central como destino de archivos e imágenes.

AirDrop estuvo disponible en esta pasada. Se abrió el selector nativo, informó que no había ninguna persona cercana y se canceló; la bandeja conservó sus tres imágenes. No se seleccionó un receptor ni se realizó un envío real.

La entrada Finder → Bandeja y la detección global quedan comprobadas a nivel de integración mediante eventos de ratón del sistema y un archivo real. Esta automatización valida el recorrido técnico completo, pero no sustituye una pasada humana para juzgar la sensación del gesto, los falsos positivos durante el uso cotidiano ni la salida Bandeja → Finder. Esos recorridos y las demás interacciones dependientes de aplicaciones externas permanecen en el checklist práctico siguiente.

## Checklist práctico pendiente

Usa los tres elementos incluidos en `Docs/QA Fixtures` y cualquier PDF de prueba. Para comprobar salida hacia Finder sin confundir origen y destino, crea manualmente una carpeta vacía fuera de `QA Fixtures`.

1. Inicia Bandeja con `⌘R` y confirma que la barra de menús muestra únicamente el logotipo de bandeja, sin el texto **Bandeja**.
2. Arrastra `archivo-prueba.txt`, haz tres inversiones horizontales rápidas sin soltar y confirma que aparece el panel.
3. Repite un arrastre recto y luego uno con correcciones normales; confirma que no aparece. Si hay falsos positivos, usa sensibilidad **Baja** y registra el patrón.
4. Deposita por separado el TXT, `imagen-prueba.svg`, un PDF y `carpeta-prueba`; luego deposítalos juntos. Suelta al menos uno exactamente sobre el centro de la miniatura compacta y otro sobre la cuadrícula desplegada. Confirma una vista previa completa para la imagen, sin zoom ni recorte, la primera página del PDF y un icono nativo para cualquier formato que Quick Look no pueda representar. La bandeja debe mantener el mismo tamaño compacto y mostrar visualmente la pila.
5. Calcula o anota tamaño y fecha de modificación de los originales antes y después. Cierra con la **X**. Confirma que los originales y el contenido de la carpeta siguen idénticos.
6. Desde la vista compacta, arrastra la pila a la carpeta de destino y confirma que salen todos los elementos. Reúne contenido otra vez, abre la cápsula y arrastra un elemento; repite con `⌘`-clic para varios. Confirma que Finder completa la operación estándar, conserva el origen y que la bandeja desaparece después de cada entrega aceptada. Cancela otro arrastre y confirma que la bandeja permanece.
7. Con varios elementos reunidos, arrastra la franja superior a cada esquina y a otra pantalla si existe. Confirma que los elementos no cambian.
8. Con contenido existente, inicia otro arrastre y sacude. Debe reaparecer o reposicionarse el mismo panel; el contador y los elementos previos deben conservarse.
9. Confirma que no existen botones para quitar ni vaciar. Pulsa la **X** y verifica que el panel desaparece, que las referencias se descartan y que los archivos originales permanecen intactos.
10. Abre el menú de la flecha y prueba **Abrir con**, **Mostrar en Finder** y **Vista rápida** con archivos no sensibles. Confirma que cada acción utiliza la experiencia nativa correspondiente.
11. Vuelve a reunir uno y varios elementos, abre **AirDrop** desde ese menú y confirma el panel nativo. Cancela una vez y verifica que la bandeja conserva su contenido. Repite con un receptor disponible solo si se desea completar un envío real. En un Mac sin AirDrop, la acción no debe anunciarse como disponible; el resto del menú debe seguir funcionando.
12. Invoca el gesto cerca de los cuatro bordes. El panel completo debe quedar dentro del área visible, incluida la barra de menús y el Dock.
13. Sal de la app desde el menú y vuelve a abrirla. Debe iniciar vacía.
14. En el primer inicio, confirma que macOS solicita **Monitorización de entrada**. Concédelo y, si macOS lo pide, reinicia Bandeja. Abre su menú y confirma **Detección global activa**; en Ajustes debe aparecer **Detección global completa**. Repite tras denegar o desactivar el permiso: ambos lugares deben indicar el modo limitado, el botón **Dar permiso…** debe abrir la ruta de recuperación y **Mostrar bandeja** debe seguir funcionando. Confirma que Bandeja no solicita Accesibilidad, Grabación de pantalla ni Automatización.
15. Abre **Ajustes…** desde el icono de menú, cambia entre las tres sensibilidades y confirma que el gesto responde según lo esperado sin reiniciar la app.
16. Activa el atajo global, elige una combinación libre y úsala desde Finder. Debe aparecer la misma bandeja, no una segunda. Prueba también una combinación ocupada: debe mostrarse un aviso y no fingir que quedó activa.
17. Con “Doble clic para mostrar el archivo en Finder” activo, haz doble clic en la tarjeta compacta y luego en un elemento expandido. Finder debe revelar el archivo. Desactívalo y confirma que el doble clic deja de hacerlo. Una imagen que solo exista en memoria no tiene carpeta que revelar.
18. Activa la detección de capturas con 3 segundos. Toma una captura guardada como archivo: una bandeja vacía debe mostrarse temporalmente y ocultarse si no recibe contenido. Cambia a 1 y 6 segundos y repite. Desactiva la opción y confirma que deja de aparecer. Repite con una captura enviada solo al portapapeles y confirma que no se detecta.
19. En macOS 26, revisa el vidrio tintado sobre fondos claros y oscuros, los estados hover y el contraste. Activa Reducir transparencia y confirma que la superficie pasa a ser sólida y legible. En macOS 14–15, confirma el material translúcido de respaldo.
20. En **Ajustes → Sistema**, activa **Abrir Bandeja al iniciar sesión** y confirma que macOS la muestra en **General → Ítems de inicio y extensiones**. Si aparece “requiere aprobación”, usa **Abrir Ajustes…** y apruébala. Cierra la sesión y vuelve a entrar para confirmar el arranque; después desactiva la opción y repite para confirmar que ya no se inicia.
21. Con otra aplicación activa, mueve la bandeja repetidas veces desde la cabecera y ciérrala con un solo clic. Repite dibujando una pequeña trayectoria de ida y vuelta al moverla: la detección global no debe reposicionar ni bloquear el panel. Si Dropover está instalado, repite primero con Dropover cerrado para descartar superposición entre ambas utilidades.
22. Desde el icono de la barra de menús, pulsa **Mostrar bandeja** sin tener archivos. La bandeja debe permanecer visible durante su intervalo normal, no desaparecer al terminar el mismo clic que abrió el menú.
23. Activa **Reducir movimiento** en macOS y repite apertura, depósito, expansión, cancelación y cierre. Las transiciones deben ser más breves y no deben cambiar la escala del contenido. Desactívalo y confirma que vuelve el movimiento sutil.
24. Inicia un arrastre sobre Finder y sobre un diálogo nativo de Abrir/Guardar. La bandeja debe mantenerse por encima mientras recibe el arrastre y volver a su nivel flotante normal al terminar.

## Criterio de aceptación

La lógica aislable, la compilación, el análisis, la detección global con permiso concedido, la entrada Finder → Bandeja, el cierre con Finder activo, los dos estados previos de interfaz, el menú de accesos y la apertura/cancelación de AirDrop están verificados. La aceptación completa de la actualización debe esperar a que una persona evalúe la naturalidad del paso 2 y marque correctos los pasos 4, 6, 7, 8, 10, 12, 13 y 15–20; completar un envío AirDrop requiere además un receptor cercano.

La construcción valida la viabilidad técnica, no la hipótesis de que el gesto resulte preferible para usuarios reales. Esa decisión necesita pruebas posteriores con personas y tareas reales.
