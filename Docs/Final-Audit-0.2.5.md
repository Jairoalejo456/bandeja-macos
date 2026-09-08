# Auditoría final del MVP 0.2.5

Fecha: 8 de septiembre de 2026. Entorno principal: Mac Apple Silicon, macOS 26.6.2, Xcode 26.6 y Swift 6.3.3. El deployment target continúa en macOS 14.0.

## Veredicto

MiniTray 0.2.5 cumple el objetivo funcional del MVP: reunir temporalmente archivos, carpetas e imágenes en una sola bandeja, conservar intactos los originales y devolver el contenido mediante drag & drop nativo. No quedaron defectos funcionales conocidos que impidan aceptar esta versión como MVP.

La auditoría encontró dos regresiones reproducibles y ambas quedaron corregidas antes de emitir este resultado:

1. Una captura creada inmediatamente después de abrir MiniTray podía quedar absorbida por la recopilación inicial de Spotlight y no mostrar la bandeja.
2. Con Finder activo, el primer intento de arrastrar una celda de la vista expandida podía limitarse a seleccionarla; el segundo sí iniciaba el arrastre.

## Matriz de aceptación

| Comportamiento | Resultado | Evidencia de esta pasada |
| --- | --- | --- |
| Gesto durante un arrastre real | Correcto | Finder abrió la bandeja con sacudidas vertical, horizontal y diagonal antes de soltar. |
| Evitar falsos positivos básicos | Correcto | Un arrastre recto y una sacudida sobre una zona vacía no abrieron la bandeja. La compuerta exige contenido importable nuevo. |
| Recibir archivos, carpetas e imágenes | Correcto | Depósitos reales de TXT, SVG y carpeta; imagen y PDF comprobados visualmente. |
| Soltar en todo el rectángulo | Correcto | El depósito real en el centro de la vista compacta fue aceptado. |
| Previsualizaciones nativas | Correcto | Se revisaron TXT, SVG, carpeta, imagen y la primera página de un PDF, con ajuste proporcional sin zoom destructivo. |
| Pila compacta y detalle | Correcto | 236 × 236 puntos con contenido; un clic abrió la cuadrícula y Atrás recuperó la pila. |
| Varios elementos y bandeja única | Correcto | Nuevos gestos conservaron el contenido y WindowServer mostró un solo panel. |
| Mover la bandeja | Correcto | La cabecera desplazó el panel 200 × 200 puntos sin perder ni bloquear contenido. |
| Arrastrar hacia Finder | Correcto | La pila completa y un elemento de la cuadrícula se copiaron en Finder; la bandeja se cerró al aceptarse la entrega. |
| Cancelar una salida | Correcto | Al soltar en un destino no compatible, la bandeja y sus referencias permanecieron. |
| Preservar originales | Correcto | Cerrar, retirar referencias y completar arrastres no alteró los archivos fuente; una incidencia de automatización se revirtió y la huella del fixture volvió a coincidir con Git. |
| Cerrar y reiniciar vacía | Correcto | La X cerró al primer clic y una nueva ejecución comenzó sin contenido. |
| Quick Look y acciones | Correcto | Quick Look mostró el TXT; el menú ofreció Abrir con, Finder, AirDrop, Mail, Mensajes y más servicios. |
| AirDrop | Parcial externo | Se abrió el panel nativo con los archivos preparados y cancelar conservó la bandeja. No se envió a un receptor real. |
| Bordes y superposición | Correcto | Las pruebas de geometría cubren todos los bordes; el panel permaneció en nivel 9, visible y con opacidad 1. |
| Permiso global | Correcto con permiso | Monitorización de entrada concedida y detección global activa. No se revocó TCC en esta pasada para no dejar la instalación inutilizable; el estado denegado tiene mensajes y apertura manual cubiertos por código. |
| Atajo global | Correcto | Control + Opción + Espacio mostró la misma bandeja; la preferencia quedó restaurada como desactivada. |
| Doble clic configurable | Correcto | Activado reveló el archivo exacto en Finder; desactivado no cambió de carpeta. Quedó restaurado como activado. |
| Detección de capturas | Correcto | Una captura real abrió la bandeja y esta se ocultó tras 2 segundos. La preferencia quedó restaurada como desactivada. |
| Inicio de sesión configurable | Correcto a nivel de servicio | Registro, desregistro y estados de aprobación pasan pruebas. No se cerró la sesión del usuario durante esta auditoría. |
| Liquid Glass y accesibilidad visual | Correcto en macOS 26 | Se revisaron vidrio tintado, recorte redondeado, contraste, icono centrado, estados compacto/expandido y ausencia del rectángulo exterior. |

## Verificación técnica

- 46 pruebas XCTest ejecutadas: 46 correctas, 0 fallos.
- Análisis estático de Release: correcto.
- `git diff --check`: correcto.
- Build de distribución: universal `arm64` y `x86_64`, macOS 14.0 o posterior.
- El estado final de las preferencias del equipo de prueba conserva sensibilidad Alta, atajo desactivado, capturas desactivadas y doble clic activado.

## Límites de la verificación

- No se completó una transferencia AirDrop porque no se seleccionó un receptor cercano; sí se verificaron preparación, apertura y cancelación nativas.
- No se cerró y reabrió la sesión de macOS para comprobar el inicio automático extremo a extremo.
- No se ejecutó esta compilación en hardware con macOS 14 o 15; esos sistemas usan el material translúcido de respaldo previsto por el código.
- Una prueba automatizada no sustituye una sesión prolongada de uso en Canva u otras aplicaciones para evaluar la sensación humana del gesto y falsos positivos poco frecuentes.
- La aplicación pública sigue sin certificado de distribución ni notarización. Eso no afecta la instalación local auditada, pero sí es necesario antes de distribuirla ampliamente.

Estos límites no constituyen defectos conocidos del flujo principal. La hipótesis de negocio y la comodidad frente a alternativas necesitan pruebas posteriores con usuarios reales.
