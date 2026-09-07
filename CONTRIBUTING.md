# Contribuir a Bandeja

Gracias por ayudar a mejorar Bandeja. El proyecto busca mantener una utilidad macOS pequeña, rápida, nativa y respetuosa con los archivos originales.

## Preparación

1. Usa macOS 14 o posterior y Xcode 26 o una versión compatible con el SDK utilizado por el proyecto.
2. Crea un fork y una rama con un nombre descriptivo.
3. Abre `Bandeja.xcodeproj`, selecciona el esquema `Bandeja` y compila para `My Mac`.
4. Ejecuta todas las pruebas antes de abrir un pull request.

```bash
xcodebuild test \
  -project Bandeja.xcodeproj \
  -scheme Bandeja \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/BandejaDerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

## Principios que deben preservarse

- La bandeja guarda referencias temporales; nunca debe mover o borrar originales.
- Solo puede existir una bandeja.
- El contenido no se restaura tras reiniciar.
- No se deben añadir telemetría, cuentas, red o permisos innecesarios.
- Las funciones globales deben explicar con honestidad cualquier limitación del sistema.
- Las interacciones deben seguir siendo accesibles con Reducir transparencia y distintos tamaños de pantalla.

## Pull requests

- Limita cada PR a un cambio coherente.
- Incluye pruebas para la lógica nueva y actualiza la documentación relevante.
- Describe las pruebas manuales realizadas y las que no pudiste comprobar.
- No añadas capturas personales, rutas locales, credenciales, certificados ni datos reales de usuarios.
- Para cambios visibles, adjunta imágenes de prueba que no contengan información privada.

Los mantenedores pueden solicitar ajustes antes de integrar un cambio. La incorporación de una contribución no implica por sí sola una nueva versión publicada.

## Versiones

El proyecto utiliza etiquetas `vMAJOR.MINOR.PATCH`. Antes de crear una versión se actualizan `CFBundleShortVersionString`, `MARKETING_VERSION` y `CHANGELOG.md`. `./scripts/build-release.sh` genera un binario universal y un ZIP local; publicar, firmar con Developer ID o notarizar son pasos separados y requieren autorización y credenciales apropiadas.
