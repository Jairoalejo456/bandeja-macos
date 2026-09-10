# Movimiento nativo — 0.2.7

Referencia: paquete de animaciones y prototipo HTML suministrados para esta actualización. No se incorporan sus archivos privados ni dependencias web a la app. Se conservan las dimensiones, identidad, miniaturas proporcionales y material nativo de MiniTray.

## Correspondencia

| Acción | Adaptación nativa |
| --- | --- |
| Entrada | 340 ms, Bézier (.2,1.1,.3,1): opacidad 0→1, escala .72→1.02→1, y +10→−2→0. Desenfoque de contenido 10→0 pt. Barrido de luz de 560 ms, recortado al vidrio. |
| Recepción | Pulso de 260 ms, escala máxima 1.035 al 42 %. Cada miniatura entra en 240 ms desde y −22, escala .86 y desenfoque 4; separación de 40 ms, limitada a 240 ms. |
| Carpeta | Proxy no interactivo en un panel transparente separado durante 380 ms. Se eleva 10 pt, viaja desde el lugar del depósito hasta el lateral de la bandeja, baja a escala .46 y desaparece. La confirmación visual empieza a los 190 ms; la importación es inmediata. |
| Expandir/colapsar | 300 ms, Bézier (.32,.72,0,1). Interpola el marco real de NSPanel desde el marco actual hacia el destino centrado y limitado al área visible. Fundido de 180 ms para compacto, 200 ms con retraso de 60 ms para expandido. |
| Salida | 200 ms, Bézier (.4,0,.75,.2), escala .9, y +6, desenfoque de contenido 6 y opacidad 0. |
| Compartir | Miniaturas: 240 ms, y −46 y escala .86, cascada de 45 ms limitada a 180 ms para lotes grandes. Panel: comienza a los 90 ms, dura 340 ms, y −34, escala .92 y desenfoque 5. |

Los 560 ms del barrido y los 430 ms totales de compartición siguen los tiempos de la referencia, aunque el texto del prototipo diga que ninguna secuencia supera 380 ms. En la cuadrícula el desenfoque se aplica a capas pequeñas de las celdas; nunca al material de fondo. El proxy usa el icono nativo de la carpeta y una trayectoria calculada en coordenadas de pantalla.

La ligera adaptación funcional de compartir es deliberada: la cascada se inicia al recibir `didShareItems`, no al abrir AirDrop/Mail. Así no se comunica visualmente un envío que todavía puede cancelarse. Mientras el selector está abierto, las referencias permanecen disponibles. Si se añadieron nuevos elementos, el resultado solo retira los IDs realmente compartidos y no cierra el resto de la bandeja.

### Confirmación común para todos los destinos

`TraySharingSession` no filtra por nombre de servicio. Los accesos directos de AirDrop, Mail y Mensajes usan el mismo delegado de confirmación; el selector de **Más opciones…** devuelve ese mismo delegado para cualquier servicio de terceros. Todos llaman a `completeSharing(ids:)` al recibir `didShareItems`. Esto significa finalización comunicada por el servicio nativo, no acuse de entrega ni de lectura del destinatario. Abrir el selector, elegir una aplicación, cancelar o fallar no dispara la animación de éxito.

**Abrir con** utiliza `NSWorkspace.open`: su callback solo confirma que se abrió el archivo, no un envío posterior. No se usa como sustituto de `didShareItems`. En la instalación de WhatsApp inspeccionada el 9 de septiembre de 2026, los dos complementos incluidos son `com.apple.usernotifications.service` y `com.apple.intents-service`, no una extensión de compartir. Tampoco apareció en la consulta local de servicios para TXT, PNG e imagen en memoria. Por eso no se afirma que un envío realizado dentro de esa app, después de **Abrir con**, pueda activar la animación. Esa ruta necesitaría una integración adicional que comunique una confirmación fiable.

La comprobación ampliada añade cuatro pruebas y deja la suite en **67 pruebas correctas, 0 fallos**. Cubre callbacks de AirDrop/Mail/Mensajes, el enrutamiento de un servicio genérico desde **Más opciones…**, espera hasta confirmación y ausencia de animación ante fallo. Son pruebas aisladas con señales de finalización inyectadas, no envíos reales ni una verificación extremo a extremo de WhatsApp. La conexión genérica ya estaba incluida en el binario 0.2.7 instalado; esta revisión añade cobertura y documentación, sin necesitar modificar ni reiniciar la app.

## Interrupciones y seguridad

- Un solo temporizador de modo común, sin listas de callbacks de fotogramas pendientes. Se detiene al quedar sin trabajo y usa tiempo monotónico real, incluso si se pierde algún fotograma.
- Cada canal se reemplaza o cancela junto con su finalización. Un cierre anterior no puede ocultar una bandeja recién abierta.
- Invertir el tamaño empieza desde el marco visible actual. Empezar a mover la cabecera o sacar archivos cancela el cambio de tamaño y asienta su geometría antes del arrastre.
- La capa saliente del fundido no contiene botones ni una segunda colección nativa interactiva. No puede interceptar clics.
- El cierre descarta las referencias inmediatamente; una copia exclusivamente visual conserva el último contenido durante la salida y se libera al terminar.
- Las nuevas URLs se publican como un lote. Los metadatos de tamaño/tipo se consultan al recopilar cada elemento, y las miniaturas no se vuelven a solicitar en cada fotograma.
- Reducir movimiento: solo opacidad durante 120 ms; sin proxy viajero, escala, desplazamiento, giro, desenfoque ni barrido. Reducir transparencia mantiene el fondo sólido de alto contraste existente.
- No se solicitan permisos nuevos, no se persisten archivos y no se amplían los tipos de contenido admitidos por el MVP.

## Comprobaciones de esta actualización

Entorno: macOS 26.6.2, Apple Silicon, Xcode 26.6. Deployment target: macOS 14.0.

- 63 XCTest, 0 fallos. Incluyen las 46 pruebas anteriores y 17 nuevas: Bézier/keyframes, tiempos, límite de cascada, movimiento reducido, reloj cancelable, 50 inversiones rápidas con 32 elementos, cerrar al redimensionar, reabrir durante la salida, arrastrar cabecera a mitad de transición, confirmación de compartir, fallo/cancelación, respuesta antigua de compartir ante una bandeja nueva vacía y proxy de carpeta cancelado sin afectar el original.
- Compilación Release universal (`arm64` y `x86_64`) y análisis estático correctos. Firma local verificada, licencia MIT incluida y `git diff --check` sin incidencias. La instalación local quedó en 0.2.7 (17), con la misma identidad de firma que la versión anterior y sin cambios de permisos.
- Se compiló y abrió una copia Debug con identidad de prueba separada. Launch Services impide iniciar el host con la misma identidad mientras la instalación normal está abierta; la copia separada permitió probar sin terminar la sesión del usuario.
- Revisión interactiva: pila compacta, un clic para expandir, un clic para regresar, cabecera arrastrable, menú de acciones y apertura/cancelación nativas de AirDrop conservando los dos elementos de prueba. El material mantiene el recorte redondeado, sin rectángulo exterior en las capturas revisadas.

### Límites explícitos

- La automatización de arrastres entre ventanas de Finder y la copia de pruebas no permitió confirmar un depósito cruzado fiable en esta pasada. La integración de recepción y salida conserva las APIs de AppKit y está cubierta por pruebas de estado/portapapeles, pero la absorción de carpeta y la salida hacia Finder necesitan una comprobación manual final en la instalación actualizada.
- No había un receptor AirDrop cercano. Se verificó el selector y su cancelación, no una transferencia real. El callback de éxito y su animación se probaron de forma aislada.
- Se compararon la composición del prototipo y sus valores de movimiento, no todos los fotogramas píxel a píxel. El tamaño, material, iconos y contenido reales difieren intencionalmente de la maqueta.
- No se revocaron permisos de la instalación normal ni se probaron físicamente macOS 14/15. No se reauditan aquí las funciones sin cambios de gesto, capturas, atajos e inicio de sesión; véase la auditoría anterior para su evidencia histórica.

## Repetición manual corta

1. Arrastrar una carpeta de Finder a cualquier parte de la bandeja, incluido el centro: debe aceptarse inmediatamente, mostrar una sola absorción y conservar el original.
2. Añadir varios archivos; alternar rápido la cápsula y Atrás. Al finalizar, el vidrio y los controles deben coincidir con una única vista pequeña o expandida.
3. Empezar a mover la cabecera o arrastrar un archivo mientras se expande: ninguna animación antigua debe mover después el panel.
4. Soltar en un destino válido de Finder: salida y cierre. Cancelar o soltar en un destino inválido: se conserva la bandeja.
5. Cancelar AirDrop: conservar contenido. Completar un envío real: cascada de salida; cualquier archivo añadido después de abrir el selector debe permanecer.
6. Repetir con Reducir movimiento y junto a los bordes de las pantallas.

Para pruebas interactivas aisladas, una compilación Debug admite `--qa-isolated --show-tray --qa-add /ruta/al/archivo`. Este modo desactiva monitores globales y usa una posición reproducible; no está disponible en Release. Debe compilarse con una identidad distinta de la aplicación instalada.
