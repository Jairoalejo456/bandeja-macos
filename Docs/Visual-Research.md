# Investigación visual y de interacción

Consulta realizada el 7 de septiembre de 2026 antes de actualizar la interfaz.

## Hallazgos aplicados

- Apple describe Liquid Glass como una capa funcional que deja ver y desenfoca el contenido posterior, recoge color y luz y puede responder al puntero. Por eso se usa en la superficie flotante y en controles concretos, no como adorno indiscriminado. Fuente: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views) y [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/).
- Las guías de Apple usan materiales para mantener contexto y establecer jerarquía. La bandeja adopta un tinte carbón translúcido, borde especular tenue, sombra profunda y texto del sistema con contraste estable. Fuente: [Materials — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/materials) y [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/356/).
- Dropover ofrece una bandeja automática para capturas y permite configurar ubicación y comportamiento; sus atajos también pueden configurarse o desactivarse. Aquí se conserva esa idea de control del usuario sin copiar interfaz, textos ni recursos. Fuentes: [Dropover — Screenshots](https://dropoverapp.com/kb/screenshots) y [Dropover — Shelf keyboard shortcuts](https://dropoverapp.com/kb/shelf-keyboard-shortcuts).
- Yoink integra acciones del sistema como Mostrar en Finder y atajos, lo que respalda usar `NSWorkspace` y una preferencia explícita para el doble clic. Fuente: [Yoink Tips](https://eternalstorms.at/yoink/mac/tips/).

## Decisiones resultantes

- macOS 26+: `glassEffect` real con tinte gris negro, forma continua e interacción en cápsulas y botones.
- macOS 14–15: material ultrafino nativo con el mismo tinte y jerarquía.
- Reducir transparencia: superficie oscura opaca para conservar legibilidad.
- Ajustes nativos y sobrios, separados de la bandeja; la ventana flotante conserva el mínimo de controles.
- El acceso rápido, la observación de capturas y el doble clic son optativos. El contenido sigue siendo exclusivamente temporal y en memoria.
