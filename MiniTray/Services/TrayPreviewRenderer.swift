import AppKit
import CoreGraphics

/// Rasteriza solo la primera página sobre papel blanco. Nunca escribe en el PDF.
enum PDFPreviewRenderer {
    static func image(for url: URL, size: CGSize, scale: CGFloat) -> NSImage? {
        guard size.width.isFinite, size.height.isFinite, scale.isFinite,
              size.width > 0, size.height > 0, scale > 0,
              let document = CGPDFDocument(url as CFURL), document.isUnlocked,
              let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox).intersection(page.getBoxRect(.mediaBox))
        guard !box.isNull, box.width.isFinite, box.height.isFinite,
              box.width > 0, box.height > 0 else { return nil }
        let sideways = abs(page.rotationAngle % 180) == 90
        let pageSize = sideways ? CGSize(width: box.height, height: box.width) : box.size
        let maximum = CGSize(width: min(size.width, 512), height: min(size.height, 512))
        let ratio = min(maximum.width / pageSize.width, maximum.height / pageSize.height)
        let density = min(scale, 4)
        let width = max(1, Int(ceil(pageSize.width * ratio * density)))
        let height = max(1, Int(ceil(pageSize.height * ratio * density)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(canvas)
        // getDrawingTransform reduce páginas grandes, pero no amplía las pequeñas.
        // Escalamos explícitamente a píxeles antes de aplicar rotación/recorte.
        let pixelRatio = min(CGFloat(width) / pageSize.width, CGFloat(height) / pageSize.height)
        context.translateBy(x: (CGFloat(width) - pageSize.width * pixelRatio) / 2,
                            y: (CGFloat(height) - pageSize.height * pixelRatio) / 2)
        context.scaleBy(x: pixelRatio, y: pixelRatio)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: pageSize),
                                                       rotate: 0, preserveAspectRatio: true))
        context.clip(to: box)
        context.drawPDFPage(page)
        guard let raster = context.makeImage() else { return nil }
        return NSImage(cgImage: raster,
                       size: CGSize(width: CGFloat(width) / density, height: CGFloat(height) / density))
    }
}

@MainActor
enum DragPreviewRenderer {
    static let maximumSize = CGSize(width: 112, height: 112)
    static let badgeDiameter: CGFloat = 16

    /// La flecha expresa intención de traslado, no aceptación del destino.
    /// El cursor nativo conserva la autoridad sobre copia/rechazo. No lo sustituimos.
    static func showsTransferBadge(for item: TrayItem, modifiers: NSEvent.ModifierFlags) -> Bool {
        item.fileURL != nil && !modifiers.contains(.option)
    }

    static func image(preview: NSImage, showTransferBadge: Bool, scale: CGFloat) -> NSImage {
        let fitted = AspectFitLayout.rect(for: preview.size,
                                          in: CGRect(origin: .zero, size: maximumSize)).size
        let contentSize = fitted == .zero ? maximumSize : fitted
        // Margen exterior para no tapar el texto del documento con el indicador.
        let size = CGSize(width: contentSize.width + 12, height: contentSize.height + 12)
        let density = min(max(scale.isFinite ? scale : 2, 1), 4)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(size.width * density)), pixelsHigh: Int(ceil(size.height * density)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return preview }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.scaleBy(x: density, y: density)
        context.clear(CGRect(origin: .zero, size: size))
        let frame = CGRect(origin: CGPoint(x: 4, y: 8), size: contentSize)
        preview.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
        if showTransferBadge {
            let badge = CGRect(x: size.width - badgeDiameter, y: 0,
                               width: badgeDiameter, height: badgeDiameter)
            // Tinta oscura fija y flecha blanca: contraste estable sobre cualquier fondo.
            NSColor(srgbRed: 0.08, green: 0.20, blue: 0.27, alpha: 1).setFill()
            NSBezierPath(ovalIn: badge).fill()
            NSColor.white.withAlphaComponent(0.85).setStroke()
            let rim = NSBezierPath(ovalIn: badge.insetBy(dx: 0.5, dy: 0.5))
            rim.lineWidth = 1
            rim.stroke()
            // Flecha vectorial: nítida en Retina, sin depender de la apariencia del sistema.
            let arrow = NSBezierPath()
            arrow.move(to: CGPoint(x: badge.minX + 4.5, y: badge.minY + 4.5))
            arrow.line(to: CGPoint(x: badge.minX + 10.5, y: badge.minY + 10.5))
            arrow.move(to: CGPoint(x: badge.minX + 5, y: badge.minY + 10.5))
            arrow.line(to: CGPoint(x: badge.minX + 10.5, y: badge.minY + 10.5))
            arrow.line(to: CGPoint(x: badge.minX + 10.5, y: badge.minY + 5))
            arrow.lineWidth = 1.6
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            NSColor.white.setStroke()
            arrow.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}

/// Actualiza únicamente las imágenes de una sesión AppKit, nunca su portapapeles
/// ni su máscara de operaciones. Se descarta al terminar/cancelar el arrastre.
@MainActor
final class TrayDragPreviewSession {
    private weak var session: NSDraggingSession?
    private var items: [TrayItem] = []
    private var scale: CGFloat = 2
    private var modifierTimer: Timer?
    private var lastCopyModifier = false

    func begin(_ session: NSDraggingSession, items: [TrayItem], scale: CGFloat) {
        end()
        self.session = session
        self.items = items
        self.scale = scale
        refresh()
        for item in items {
            guard let url = item.fileURL else { continue }
            guard NativeThumbnailLoader.shared.cachedThumbnail(for: url, scale: scale) == nil else { continue }
            NativeThumbnailLoader.shared.loadThumbnail(for: url, size: DragPreviewRenderer.maximumSize, scale: scale) {
                [weak self, weak session] _ in
                guard let self, let session, self.session === session else { return }
                self.refresh(itemID: item.id)
            }
        }
        // AppKit no informa al origen de todos los cambios de destino. Solo leemos
        // Opción para retirar la flecha al pedir copia, incluso sin mover el cursor.
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.session != nil else { self.end(); return }
                if NSEvent.modifierFlags.contains(.option) != self.lastCopyModifier { self.refresh() }
            }
        }
        modifierTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func end() {
        modifierTimer?.invalidate()
        modifierTimer = nil
        session = nil
        items = []
    }

    private func refresh(itemID: UUID? = nil) {
        guard let session else { end(); return }
        let modifiers = NSEvent.modifierFlags
        lastCopyModifier = modifiers.contains(.option)
        let badgeID = items.first(where: { $0.fileURL != nil })?.id
        session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) {
            [self] draggingItem, index, _ in
            guard let item = Self.matchingItem(draggingItem.item, index: index, items: items),
                  itemID == nil || item.id == itemID else { return }
            let preview = item.fileURL.flatMap { NativeThumbnailLoader.shared.cachedThumbnail(for: $0, scale: scale) }
                ?? item.displayImage
            let image = DragPreviewRenderer.image(preview: preview,
                showTransferBadge: item.id == badgeID && DragPreviewRenderer.showsTransferBadge(for: item, modifiers: modifiers),
                scale: scale)
            let old = draggingItem.draggingFrame
            let frame = CGRect(x: old.midX - image.size.width / 2, y: old.midY - image.size.height / 2,
                               width: image.size.width, height: image.size.height)
            draggingItem.setDraggingFrame(frame, contents: image)
        }
    }

    static func matchingItem(_ value: Any, index: Int, items: [TrayItem]) -> TrayItem? {
        let url: URL?
        if let pasteboardItem = value as? NSPasteboardItem {
            url = pasteboardItem.string(forType: .fileURL).flatMap(URL.init(string:))
        } else {
            url = value as? URL
        }
        if let url {
            return items.first { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }
        }
        return items.indices.contains(index) ? items[index] : nil
    }

    deinit { modifierTimer?.invalidate() }
}
