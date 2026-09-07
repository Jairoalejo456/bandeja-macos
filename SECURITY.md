# Seguridad

## Informar una vulnerabilidad

No publiques vulnerabilidades explotables, credenciales ni datos personales en un issue público. Utiliza la función **Report a vulnerability** de la pestaña Security del repositorio para enviar un aviso privado mediante GitHub Security Advisories.

Incluye una descripción, versiones afectadas, pasos mínimos para reproducir y el impacto esperado. Utiliza archivos ficticios o sanitizados.

## Alcance

El MVP no utiliza servidores, cuentas, analítica ni sincronización. Los puntos sensibles principales son el acceso a URLs entregadas mediante drag & drop, la publicación temporal en `NSPasteboard`, la detección de capturas mediante Spotlight y los servicios de compartir iniciados expresamente por el usuario.
