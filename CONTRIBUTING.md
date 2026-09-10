# Contribuir a MiniTray

Gracias por ayudar a mejorar MiniTray. El proyecto busca mantener una utilidad macOS pequeña, rápida, nativa y respetuosa con los archivos originales.

## Preparación

1. Usa macOS 14 o posterior y Xcode 26 o posterior con el SDK que contiene las APIs de Liquid Glass.
2. Crea un fork y una rama con un nombre descriptivo.
3. Abre `MiniTray.xcodeproj`, selecciona el esquema `MiniTray` y compila para `My Mac`.
4. Ejecuta todas las pruebas antes de abrir un pull request.

```bash
xcodebuild test \
  -project MiniTray.xcodeproj \
  -scheme MiniTray \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/MiniTrayDerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

## Principios que deben preservarse

- Recoger, cancelar y cerrar solo cambian referencias temporales; no deben mover ni borrar originales. Una salida deliberada puede negociar movimiento o copia con Finder. MiniTray no debe borrar el origen por su cuenta después de la entrega.
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

## Licencia de las contribuciones

MiniTray usa la [licencia MIT](LICENSE). Al enviar una contribución para integrarla en el proyecto, la ofreces bajo esa misma licencia. Incluye únicamente código y recursos que tengas derecho a aportar y conserva los avisos de autoría aplicables.

## Versiones

El proyecto utiliza etiquetas `vMAJOR.MINOR.PATCH`. Antes de crear una versión se actualizan `MARKETING_VERSION` (que alimenta `CFBundleShortVersionString`), `CURRENT_PROJECT_VERSION` y `CHANGELOG.md`. `./scripts/build-release.sh` genera un binario universal y un ZIP local.

Las entregas terminadas solicitadas por el propietario deben quedar también en GitHub, no únicamente instaladas en su Mac:

1. Revisar cambios, privacidad, licencia y pruebas; documentar las verificaciones pendientes sin presentarlas como superadas.
2. Guardar el código, pruebas y documentación en un commit y subirlo al repositorio oficial. Excluir configuraciones locales, certificados, credenciales, capturas personales y resultados temporales.
3. Esperar la comprobación de GitHub Actions. Crear la etiqueta correspondiente y una GitHub Release con notas en `Docs/Releases`, ZIP universal y su SHA-256.
4. Verificar que etiqueta, código, versión del binario y huella publicada corresponden a la misma entrega. Informar los enlaces de código y descarga.

La publicación de estas entregas está autorizada por el propietario. Esa autorización no incluye compras, creación de certificados, firma con Developer ID, notarización ni cambios en cuentas de Apple, que siguen siendo pasos separados.
