import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TrayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: TrayStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var visualState: TrayVisualState
    let isExpanded: Bool
    let onClose: () -> Void
    let onExpand: () -> Void
    let onCollapse: () -> Void
    let onExternalDragBegan: () -> Void
    let onExternalDragCompleted: (NSDragOperation) -> Void

    var body: some View {
        Group {
            if isExpanded {
                expandedContent
            } else {
                compactContent
            }
        }
        .background {
            TrayGlassSurface(cornerRadius: 20)
        }
        .overlay {
            if store.isDropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
        .padding(8)
        .scaleEffect(visualState.scale)
        .opacity(visualState.opacity)
        .animation(responsiveAnimation, value: store.isDropTargeted)
        .animation(responsiveAnimation, value: store.isDraggingOut)
        .environment(\.controlActiveState, .active)
        .environment(\.colorScheme, .dark)
    }

    private var compactContent: some View {
        VStack(spacing: 0) {
            compactHeader

            if store.items.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    previewStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Button(action: onExpand) {
                        HStack(spacing: 5) {
                            Text(compactCountText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background {
                            TrayGlassCapsuleBackground()
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Ver todos los elementos")
                    .accessibilityLabel("Ver \(compactCountText)")
                    .opacity(secondaryControlOpacity)
                    .allowsHitTesting(!store.isDraggingOut)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    private var compactHeader: some View {
        ZStack {
            WindowDragHandle()

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(TrayIconButtonStyle())
                .help("Cerrar y cancelar esta bandeja")

                Spacer()

                TrayActionsButton(items: store.items)
                    .frame(width: 38, height: 38)
            }
            .padding(.horizontal, 8)
            .zIndex(1)
            .opacity(secondaryControlOpacity)
            .allowsHitTesting(!store.isDraggingOut)
        }
        .frame(height: 46)
    }

    private var previewStack: some View {
        ZStack {
            ForEach(Array(store.items.prefix(3).enumerated()).reversed(), id: \.element.id) { index, item in
                NativeThumbnailView(item: item, size: NSSize(width: 120, height: 94))
                    .frame(width: 120, height: 94)
                    .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(index == 0 ? 0.20 : 0.10), radius: 4, y: 2)
                    .rotationEffect(rotation(for: index))
                    .offset(offset(for: index))
            }

            CompactDragSourceView(
                store: store,
                items: store.items,
                onBegan: onExternalDragBegan,
                onCompleted: onExternalDragCompleted,
                onDoubleClick: revealFrontItemInFinder
            )
                .frame(width: 154, height: 112)
                .contentShape(Rectangle())
                .help("Arrastra todos los elementos")
        }
        .frame(height: 112)
        .scaleEffect(previewScale)
        .opacity(previewOpacity)
        .accessibilityElement(children: .contain)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            expandedHeader

            Divider()
                .opacity(0.5)

            ZStack {
                TrayCollectionView(
                    store: store,
                    revealInFinderOnDoubleClick: settings.revealInFinderOnDoubleClick,
                    onExternalDragBegan: onExternalDragBegan,
                    onExternalDragCompleted: onExternalDragCompleted
                )
                .scaleEffect(store.isDraggingOut ? 0.985 : 1)
                .opacity(store.isDraggingOut ? 0.58 : 1)

                if store.items.isEmpty {
                    emptyState
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var expandedHeader: some View {
        ZStack {
            WindowDragHandle()

            VStack(spacing: 1) {
                Text(expandedCountText)
                    .font(.system(size: 15, weight: .semibold))
                if let totalSizeText {
                    Text(totalSizeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .allowsHitTesting(false)

            HStack {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(TrayIconButtonStyle())
                .help("Volver a la vista compacta")

                Spacer()

                TrayActionsButton(items: store.items)
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 8)
            .zIndex(1)
            .opacity(secondaryControlOpacity)
            .allowsHitTesting(!store.isDraggingOut)
        }
        .frame(height: 54)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(store.isDropTargeted ? Color.accentColor : Color.primary.opacity(0.54))
                .symbolEffect(.bounce, value: store.isDropTargeted)

            Text(store.isDropTargeted ? "Suelta para reunir" : "Suelta archivos aquí")
                .font(.system(size: 13, weight: .semibold))

            Text("Los originales no cambian")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func rotation(for index: Int) -> Angle {
        switch index {
        case 1: return .degrees(-5)
        case 2: return .degrees(5)
        default: return .zero
        }
    }

    private func offset(for index: Int) -> CGSize {
        switch index {
        case 1: return CGSize(width: -8, height: -3)
        case 2: return CGSize(width: 8, height: -1)
        default: return .zero
        }
    }

    private var compactCountText: String {
        let count = store.items.count
        if itemsAreAllImages {
            return count == 1 ? "1 imagen" : "\(count) imágenes"
        }
        return count == 1 ? "1 elemento" : "\(count) elementos"
    }

    private var expandedCountText: String {
        compactCountText.prefix(1).uppercased() + compactCountText.dropFirst()
    }

    private var itemsAreAllImages: Bool {
        !store.items.isEmpty && store.items.allSatisfy { item in
            switch item.content {
            case .image:
                return true
            case let .file(url):
                guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
                return type.conforms(to: .image)
            }
        }
    }

    private var totalSizeText: String? {
        let byteCount = store.items.reduce(Int64.zero) { partial, item in
            switch item.content {
            case let .image(data, _):
                return partial + Int64(data.count)
            case let .file(url):
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                return partial + Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            }
        }
        guard byteCount > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private var responsiveAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .spring(response: 0.22, dampingFraction: 0.82)
    }

    private var secondaryControlOpacity: Double {
        store.isDraggingOut ? 0.24 : 1
    }

    private var previewOpacity: Double {
        store.isDraggingOut ? 0.60 : 1
    }

    private var previewScale: CGFloat {
        if store.isDraggingOut { return 0.97 }
        if store.isDropTargeted { return 1.025 }
        return 1
    }

    private func revealFrontItemInFinder() {
        guard settings.revealInFinderOnDoubleClick,
              let url = store.items.first?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct TrayIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.84))
            .background {
                TrayGlassCircleBackground(isPressed: configuration.isPressed)
            }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TrayGlassSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.105, blue: 0.115))
            } else if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(
                        .regular.tint(Color(red: 0.07, green: 0.075, blue: 0.085).opacity(0.76)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.06, blue: 0.07).opacity(0.74))
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.075), Color.clear, Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        }
    }
}

private struct TrayGlassCapsuleBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Capsule().fill(Color.white.opacity(0.14))
        } else if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.28)).interactive(), in: Capsule())
        } else {
            Capsule().fill(Color.white.opacity(0.12))
        }
    }
}

private struct TrayGlassCircleBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let isPressed: Bool

    var body: some View {
        if reduceTransparency {
            Circle().fill(Color.white.opacity(isPressed ? 0.20 : 0.13))
        } else if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular
                        .tint(Color.black.opacity(isPressed ? 0.34 : 0.24))
                        .interactive(),
                    in: Circle()
                )
        } else {
            Circle().fill(Color.white.opacity(isPressed ? 0.20 : 0.11))
        }
    }
}
