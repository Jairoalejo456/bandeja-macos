# Privacidad

MiniTray funciona localmente y no transmite telemetría ni datos a un servidor propio.

- Los elementos reunidos se conservan únicamente en memoria durante la sesión.
- Cerrar o vaciar la bandeja descarta referencias, no archivos originales.
- La aplicación no incluye cuenta, autenticación, analítica ni sincronización.
- La detección opcional de capturas consulta metadatos Spotlight de archivos marcados por macOS como capturas; no graba ni observa el contenido de la pantalla.
- El atajo global registra una combinación concreta con macOS; no registra lo que el usuario escribe.
- Durante un arrastre de salida se consulta el estado de Opción para adaptar el indicador de movimiento/copia; no se capturan caracteres ni se guarda un historial de teclas.
- AirDrop, Mail, Mensajes y otros destinos solo reciben elementos cuando el usuario elige expresamente ese servicio en el menú nativo.

Cerrar vacía la colección de la bandeja. Las miniaturas en caché y la última selección de Quick Look pueden seguir temporalmente en memoria hasta sustituirse o terminar la aplicación. MiniTray no las persiste para recuperar bandejas; las cachés que administran los servicios de macOS quedan bajo control del sistema.

El proyecto no solicita Accesibilidad, Grabación de pantalla, Automatización ni acceso completo al disco. Una futura versión que cambie estas condiciones deberá actualizar este documento antes de publicarse.
