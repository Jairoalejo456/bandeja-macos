# Privacidad

Bandeja funciona localmente y no transmite telemetría ni datos a un servidor propio.

- Los elementos reunidos se conservan únicamente en memoria durante la sesión.
- Cerrar o vaciar la bandeja descarta referencias, no archivos originales.
- La aplicación no incluye cuenta, autenticación, analítica ni sincronización.
- La detección opcional de capturas consulta metadatos Spotlight de archivos marcados por macOS como capturas; no graba ni observa el contenido de la pantalla.
- El atajo global registra una combinación concreta con macOS; no registra lo que el usuario escribe.
- AirDrop, Mail, Mensajes y otros destinos solo reciben elementos cuando el usuario elige expresamente ese servicio en el menú nativo.

El proyecto no solicita Accesibilidad, Grabación de pantalla, Automatización ni acceso completo al disco. Una futura versión que cambie estas condiciones deberá actualizar este documento antes de publicarse.
