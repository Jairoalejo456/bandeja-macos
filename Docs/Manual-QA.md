# Verificación manual de MiniTray

La auditoría ejecutada del MVP 0.2.5 y sus resultados están documentados en [Final-Audit-0.2.5.md](Final-Audit-0.2.5.md). Esta lista permite repetir la aceptación en otro Mac o después de cambios futuros.

Usa los elementos de `Docs/QA Fixtures`, una imagen raster y un PDF. Para probar la salida, crea una carpeta de destino vacía fuera de los fixtures y anota antes las fechas, tamaños o huellas de los originales.

## Flujo principal

1. Abre MiniTray y confirma que solo aparece su logotipo en la barra de menús y que no restaura contenido anterior.
2. Arrastra un archivo desde Finder. Sin soltar, haz tres cambios rápidos de dirección en horizontal, vertical y diagonal. En cada caso debe aparecer la misma bandeja cerca del cursor y dentro de la pantalla.
3. Haz un arrastre recto, selecciona texto y mueve un objeto no exportable dentro de otra aplicación. La bandeja no debe aparecer.
4. Deposita un archivo, varios archivos, una carpeta, una imagen y un PDF; suelta al menos uno en el centro exacto. Todas las zonas internas deben aceptar el contenido.
5. Comprueba miniatura proporcional de la imagen, primera página del PDF, vistas nativas para formatos compatibles e iconos de Finder como respaldo.
6. Confirma que la pila compacta mantiene 236 × 236 puntos sin importar la cantidad. Pulsa una vez la cápsula, revisa todos los elementos en la cuadrícula y vuelve con Atrás.
7. Arrastra la cabecera a diferentes zonas y bordes. La bandeja debe responder al primer intento, quedar visible y conservar todo.
8. Con contenido existente, repite el gesto con otro archivo. No debe aparecer una segunda bandeja ni perderse el contenido anterior.
9. Arrastra la pila compacta a Finder y luego un elemento o selección desde la cuadrícula. La entrega debe comenzar al primer intento y la bandeja debe cerrarse cuando el destino la acepte.
10. Cancela otra salida. La bandeja debe recuperar sus controles y conservar el contenido.
11. Pulsa X con otra aplicación activa. Debe responder al primer clic, cerrar el panel y olvidar las referencias sin alterar los originales.
12. Verifica que todos los originales mantienen su ubicación, tamaño, fecha o huella después de depositar, sacar, cancelar y cerrar.

## Acciones y ajustes

13. Abre el menú de acciones y prueba Abrir con, Mostrar en Finder y Vista rápida.
14. Abre AirDrop con uno y varios elementos. Cancela una vez y confirma que el contenido permanece. Si hay receptor disponible y se autoriza, completa un envío.
15. Activa el doble clic para revelar en Finder y pruébalo en vista compacta y expandida; desactívalo y confirma que deja de actuar.
16. Activa un atajo global libre y comprueba que abre la misma bandeja desde Finder. Si la combinación está ocupada, MiniTray debe informar el conflicto.
17. Activa la detección de capturas, prueba varios intervalos y toma una captura guardada. La bandeja vacía debe aparecer y ocultarse tras el intervalo si no recibe nada. Una captura solo al portapapeles no debe activarla.
18. Cambia entre las tres sensibilidades sin reiniciar y comprueba que el gesto sigue siendo deliberado.
19. Activa y desactiva Abrir al iniciar sesión; revisa su estado en General → Ítems de inicio. Para aceptación completa, cierra sesión y verifica ambos estados.

## Sistema y apariencia

20. Concede Monitorización de entrada y comprueba el estado global activo. Desactívalo temporalmente y verifica el mensaje de modo limitado, el acceso para recuperarlo y la apertura manual; luego restáuralo.
21. En macOS 26 revisa Liquid Glass sobre fondos claros y oscuros. No debe existir un rectángulo exterior, el icono vacío debe estar centrado y el contenido no debe atenuarse al cambiar de foco.
22. Activa Reducir transparencia y Reducir movimiento. La bandeja debe conservar contraste y usar transiciones breves sin desincronizar sus zonas de clic.
23. En macOS 14 o 15 confirma el material translúcido de respaldo y repite el flujo principal.
24. Si Dropover está instalado, repite movimiento y cierre con Dropover cerrado para descartar superposición entre utilidades.

## Registro de la pasada

Anota versión de MiniTray, versión de macOS, modelo del Mac, resultado por paso, archivos usados, capturas relevantes y cualquier diferencia reproducible. No declares verificados AirDrop a un receptor, un ciclo completo de inicio de sesión ni compatibilidad con otra versión de macOS si no se ejecutaron realmente.
