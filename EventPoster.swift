import Foundation
import CoreGraphics
import AppKit

enum MouseKind { case left, right, middle }

/// Cria e posta eventos de mouse/scroll/teclado. Exige permissão de Acessibilidade
/// e que o App Sandbox esteja DESLIGADO.
final class EventPoster {
    private let source = CGEventSource(stateID: .hidSystemState)

    private var leftDown = false
    private var rightDown = false
    private var middleDown = false

    // Posição "virtual" para não perder movimentos menores que 1 pixel.
    private var tracked: CGPoint?
    private var lastCursorSync: TimeInterval = 0
    private var displayBounds = CGRect.null
    private var lastDisplayBoundsCheck: TimeInterval = 0

    // Controle de duplo clique.
    private var lastClickTime: TimeInterval = 0
    private var lastClickPoint = CGPoint.zero
    private var clickCount: Int64 = 0

    // Acumuladores de scroll (a API só aceita inteiros).
    private var scrollAccumX = 0.0
    private var scrollAccumY = 0.0

    var cursor: CGPoint { CGEvent(source: nil)?.location ?? .zero }

    // MARK: Mouse

    func moveCursor(dx: Double, dy: Double) {
        guard dx != 0 || dy != 0 else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if tracked == nil || now - lastCursorSync >= 1.0 / 30.0 {
            let real = cursor
            if let tracked, hypot(real.x - tracked.x, real.y - tracked.y) <= 2 {
                // Keep the fractional position accumulated by the controller.
            } else {
                tracked = real // o usuário mexeu o cursor por outro meio
            }
            lastCursorSync = now
        }

        guard var p = tracked else { return }
        p.x += dx
        p.y += dy
        p = clamp(p)
        tracked = p

        let type: CGEventType
        let button: CGMouseButton
        if leftDown { type = .leftMouseDragged; button = .left }
        else if rightDown { type = .rightMouseDragged; button = .right }
        else if middleDown { type = .otherMouseDragged; button = .center }
        else { type = .mouseMoved; button = .left }

        let e = CGEvent(mouseEventSource: source, mouseType: type,
                        mouseCursorPosition: p, mouseButton: button)
        e?.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx.rounded()))
        e?.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy.rounded()))
        e?.post(tap: .cghidEventTap)
    }

    func setMouse(_ kind: MouseKind, down: Bool) {
        let p = cursor
        let downType: CGEventType
        let upType: CGEventType
        let button: CGMouseButton
        switch kind {
        case .left:   downType = .leftMouseDown;  upType = .leftMouseUp;  button = .left
        case .right:  downType = .rightMouseDown; upType = .rightMouseUp; button = .right
        case .middle: downType = .otherMouseDown; upType = .otherMouseUp; button = .center
        }

        if down {
            let now = ProcessInfo.processInfo.systemUptime
            let near = hypot(p.x - lastClickPoint.x, p.y - lastClickPoint.y) < 5
            if now - lastClickTime < NSEvent.doubleClickInterval && near {
                clickCount += 1
            } else {
                clickCount = 1
            }
            lastClickTime = now
            lastClickPoint = p
        }

        let e = CGEvent(mouseEventSource: source, mouseType: down ? downType : upType,
                        mouseCursorPosition: p, mouseButton: button)
        e?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        e?.post(tap: .cghidEventTap)

        switch kind {
        case .left: leftDown = down
        case .right: rightDown = down
        case .middle: middleDown = down
        }
    }

    func scroll(dx: Double, dy: Double) {
        scrollAccumX += dx
        scrollAccumY += dy
        let ix = Int32(scrollAccumX)
        let iy = Int32(scrollAccumY)
        guard ix != 0 || iy != 0 else { return }
        scrollAccumX -= Double(ix)
        scrollAccumY -= Double(iy)

        let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                        wheel1: iy, wheel2: ix, wheel3: 0)
        e?.post(tap: .cghidEventTap)
    }

    // MARK: Teclado

    func key(_ shortcut: Shortcut, down: Bool, autorepeat: Bool = false) {
        let e = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.keyCode),
                        keyDown: down)
        e?.flags = shortcut.flags
        if autorepeat {
            e?.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        }
        e?.post(tap: .cghidEventTap)
    }

    /// Sends the modifier as its own key event so macOS recognizes this system shortcut.
    func showMissionControl() {
        let controlKey = CGKeyCode(59)
        let upArrow = CGKeyCode(Shortcut.missionControl.keyCode)

        guard let controlDown = CGEvent(keyboardEventSource: source, virtualKey: controlKey, keyDown: true),
              let arrowDown = CGEvent(keyboardEventSource: source, virtualKey: upArrow, keyDown: true),
              let arrowUp = CGEvent(keyboardEventSource: source, virtualKey: upArrow, keyDown: false),
              let controlUp = CGEvent(keyboardEventSource: source, virtualKey: controlKey, keyDown: false) else {
            return
        }

        controlDown.flags = .maskControl
        arrowDown.flags = .maskControl
        arrowUp.flags = .maskControl
        controlUp.flags = []

        controlDown.post(tap: .cghidEventTap)
        arrowDown.post(tap: .cghidEventTap)
        arrowUp.post(tap: .cghidEventTap)
        controlUp.post(tap: .cghidEventTap)
    }

    // MARK: Utilidades

    /// Solta tudo o que estiver pressionado (usado ao desativar/desconectar).
    func releaseAll() {
        if leftDown { setMouse(.left, down: false) }
        if rightDown { setMouse(.right, down: false) }
        if middleDown { setMouse(.middle, down: false) }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        let now = ProcessInfo.processInfo.systemUptime
        if displayBounds.isNull || now - lastDisplayBoundsCheck >= 2 {
            refreshDisplayBounds(at: now)
        }
        guard !displayBounds.isNull else { return p }

        return CGPoint(x: min(max(p.x, displayBounds.minX), displayBounds.maxX - 1),
                       y: min(max(p.y, displayBounds.minY), displayBounds.maxY - 1))
    }

    private func refreshDisplayBounds(at time: TimeInterval) {
        lastDisplayBoundsCheck = time

        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return }

        var bounds = CGRect.null
        for id in ids {
            bounds = bounds.union(CGDisplayBounds(id))
        }
        displayBounds = bounds
    }
}
