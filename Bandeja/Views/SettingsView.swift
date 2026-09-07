import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsHeader
                activationSection
                screenshotSection
                filesSection
            }
            .padding(24)
        }
        .frame(width: 540, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("Ajustes")
                    .font(.system(size: 20, weight: .semibold))
                Text("Configura cómo y cuándo aparece.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activationSection: some View {
        SettingsGroup(title: "Aparición", systemImage: "cursorarrow.motionlines") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Velocidad de la sacudida")
                            .font(.system(size: 13, weight: .medium))
                        Text("Baja exige movimientos más rápidos y amplios.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.shakeSensitivity) {
                        ForEach(GlobalDragMonitor.Sensitivity.allCases, id: \.self) { sensitivity in
                            Text(sensitivity.rawValue).tag(sensitivity)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Divider()

                Toggle("Activar atajo global para mostrar la bandeja", isOn: $settings.shortcutEnabled)
                    .font(.system(size: 13, weight: .medium))

                HStack {
                    Text("Atajo")
                        .font(.system(size: 12))
                        .foregroundStyle(settings.shortcutEnabled ? .primary : .secondary)
                    Spacer()
                    Picker("Atajo", selection: $settings.shortcutPreset) {
                        ForEach(GlobalShortcutPreset.allCases) { shortcut in
                            Text(shortcut.displayName).tag(shortcut)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .disabled(!settings.shortcutEnabled)
                }

                if let status = settings.shortcutStatus {
                    Label(status, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var screenshotSection: some View {
        SettingsGroup(title: "Capturas de pantalla", systemImage: "camera.viewfinder") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Mostrar temporalmente la bandeja al detectar una captura", isOn: $settings.screenshotDetectionEnabled)
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 12) {
                    Text("Tiempo visible")
                        .font(.system(size: 12))
                        .foregroundStyle(settings.screenshotDetectionEnabled ? .primary : .secondary)

                    Slider(value: $settings.screenshotTrayDuration, in: 1...10, step: 0.5)
                        .disabled(!settings.screenshotDetectionEnabled)

                    Text(durationText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                        .foregroundStyle(settings.screenshotDetectionEnabled ? .primary : .secondary)
                }

                Text("Detecta capturas guardadas por macOS mediante Spotlight. Las capturas copiadas únicamente al portapapeles no generan un archivo detectable.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let status = settings.screenshotStatus {
                    Label(status, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var filesSection: some View {
        SettingsGroup(title: "Archivos", systemImage: "folder") {
            VStack(alignment: .leading, spacing: 5) {
                Toggle("Doble clic para mostrar el archivo en Finder", isOn: $settings.revealInFinderOnDoubleClick)
                    .font(.system(size: 13, weight: .medium))
                Text("Funciona sobre la previsualización compacta y sobre cada elemento de la cuadrícula.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    private var durationText: String {
        settings.screenshotTrayDuration.formatted(.number.precision(.fractionLength(settings.screenshotTrayDuration.rounded() == settings.screenshotTrayDuration ? 0 : 1))) + " s"
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .padding(.top, 4)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
        }
        .groupBoxStyle(.automatic)
    }
}
