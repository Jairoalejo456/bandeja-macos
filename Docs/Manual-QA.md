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

La versión 0.1.2 añade un monitor pasivo de Core Graphics y solicita Monitorización de entrada para detectar de forma fiable los arrastres que pertenecen a Finder u otra aplicación. La máscara automatizada se comprobó: incluye únicamente pulsación, arrastre y liberación del botón izquierdo, y excluye teclado y botón derecho. La concesión real del permiso depende de una decisión del usuario en macOS y queda pendiente de validación manual después de instalar esta compilación.

La corrección 0.1.1 también se comprobó contra WindowServer con el botón izquierdo mantenido y una trayectoria horizontal de tres inversiones: el gesto creó un único panel visible de 264 × 180 puntos, nivel flotante y opacidad 1 antes de soltar. Una trayectoria recta equivalente produjo cero ventanas, como se esperaba. Esta prueba recorre el muestreo global, el detector y la aparición real del `NSPanel`; no sustituye todavía el arrastre manual de un archivo desde Finder.

Se ejecutaron **26 pruebas XCTest, 26 correctas, 0 fallos**:

- 8 del detector: sacudida deliberada, arrastre normal, microtemblor, gesto lento, movimiento vertical dominante, reinicio al soltar y dos pruebas del muestreo global del botón;
- 9 del estado: referencias sin modificación del original, varios archivos y carpetas, duplicados, entradas inválidas, imágenes en memoria, cierre al quedar vacío, expansión/contracción, salida cancelada y salida aceptada preservando el archivo real;
- 2 de `NSPasteboard`: varias URLs reales e imagen sin URL;
- 2 de ventana: colocación en las cuatro esquinas y el centro del área visible, y tamaño compacto idéntico con 1 o 32 elementos con límite desplazable al expandir.
- 5 de configuración, privacidad y capturas: valores iniciales prudentes, persistencia independiente del contenido, filtro de capturas recientes, combinaciones distintas de atajos y máscara del monitor limitada al ratón.

AirDrop estuvo disponible en esta pasada. Se abrió el selector nativo, informó que no había ninguna persona cercana y se canceló; la bandeja conservó sus tres imágenes. No se seleccionó un receptor ni se realizó un envío real.

La herramienta de automatización disponible no puede sostener un arrastre mientras describe una trayectoria de varias inversiones ni completar de forma fiable un drag entre dos procesos. Por ello, los recorridos Finder ↔ Bandeja, la sacudida global real y el movimiento manual del panel requieren la pasada práctica siguiente antes de aceptar el MVP. La implementación no se presenta como verificada en esos puntos.

## Checklist práctico pendiente

Usa los tres elementos incluidos en `Docs/QA Fixtures` y cualquier PDF de prueba. Para comprobar salida hacia Finder sin confundir origen y destino, crea manualmente una carpeta vacía fuera de `QA Fixtures`.

1. Inicia Bandeja con `⌘R` y confirma el texto **Bandeja** junto a su icono en la barra de menús.
2. Arrastra `archivo-prueba.txt`, haz tres inversiones horizontales rápidas sin soltar y confirma que aparece el panel.
3. Repite un arrastre recto y luego uno con correcciones normales; confirma que no aparece. Si hay falsos positivos, usa sensibilidad **Baja** y registra el patrón.
4. Deposita por separado el TXT, `imagen-prueba.svg`, un PDF y `carpeta-prueba`; luego deposítalos juntos. Confirma una vista previa real para la imagen y la primera página del PDF, y un icono nativo para cualquier formato que Quick Look no pueda representar. La bandeja debe mantener el mismo tamaño compacto y mostrar visualmente la pila.
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

## Criterio de aceptación

La lógica aislable, la compilación, el análisis, los dos estados previos de interfaz, el menú de accesos y la apertura/cancelación de AirDrop están verificados. La aceptación completa de la actualización debe esperar a que una persona marque correctos los pasos 2, 4, 6, 7, 8, 10, 12, 13 y 15–19 en un entorno con interacción real; completar un envío AirDrop requiere además un receptor cercano.

La construcción valida la viabilidad técnica, no la hipótesis de que el gesto resulte preferible para usuarios reales. Esa decisión necesita pruebas posteriores con personas y tareas reales.
