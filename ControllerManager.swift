import Foundation
import AppKit
import Combine
import ApplicationServices
@preconcurrency import GameController

@MainActor
final class ControllerManager: ObservableObject {

    // MARK: Estado exposto à interface

    @Published var controllerName: String?
    @Published var batteryText: String?
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var lastPressed = "—"
    @Published private(set) var pressedButtons: Set<PadButton> = []
    @Published private(set) var controllerInput = ControllerInputState.zero
    @Published var isTestingController = false {
        didSet {
            if isTestingController && !oldValue {
                releaseEverything()
            } else if !isTestingController {
                controllerInput = .zero
            }
        }
    }
    @Published var settings: PadSettings {
        didSet {
            save()
            if !settings.enabled { releaseEverything() }
            updateInputActivity()
        }
    }

    // MARK: Interno

    private let poster = EventPoster()
    private var pad: GCDualSenseGamepad?
    private var controller: GCController?
    private var timer: Timer?
    private var inputActivity: (any NSObjectProtocol)?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastBatteryCheck: TimeInterval = 0
    private var lastDiagnosticsUpdate: TimeInterval = 0

    // Teclas seguradas, para repetir (setas, por exemplo).
    private struct Held { var shortcut: Shortcut; var nextRepeat: TimeInterval }
    private var held: [PadButton: Held] = [:]
    private let repeatDelay = 0.40
    private let repeatInterval = 0.045

    private var lastTouch: (x: Float, y: Float)?
    private var lastButton: PadButton?
    private var lastButtonPressed: Bool?

    private static let storeKey = "dualpad.settings.v1"

    // MARK: Início

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let s = try? JSONDecoder().decode(PadSettings.self, from: data) {
            settings = s
        } else {
            settings = PadSettings()
        }

        // Faz o controle funcionar com o app em segundo plano.
        GCController.shouldMonitorBackgroundEvents = true

        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let c = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.attach(c) }
        }
        nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let c = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.detach(c) }
        }
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccessibility() }
        }

        for c in GCController.controllers() { attach(c) }
        if controller == nil {
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }

        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Permissão de Acessibilidade

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func refreshAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func refreshLocalizedStrings() {
        updateBattery()
        if let lastButton, let lastButtonPressed {
            lastPressed = "\(lastButton.title) \(AppLanguage.text(lastButtonPressed ? "pressionado" : "solto"))"
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Conexão

    private func attach(_ c: GCController) {
        // Só aceita DualSense.
        guard let ds = c.extendedGamepad as? GCDualSenseGamepad else { return }

        controller = c
        pad = ds
        updateInputActivity()
        controllerName = c.vendorName ?? "DualSense"
        updateBattery()

        bind(ds.buttonA, .cross)
        bind(ds.buttonB, .circle)
        bind(ds.buttonX, .square)
        bind(ds.buttonY, .triangle)
        bind(ds.leftShoulder, .l1)
        bind(ds.rightShoulder, .r1)
        bind(ds.leftTrigger, .l2)
        bind(ds.rightTrigger, .r2)
        bind(ds.leftThumbstickButton, .l3)
        bind(ds.rightThumbstickButton, .r3)
        bind(ds.dpad.up, .dpadUp)
        bind(ds.dpad.down, .dpadDown)
        bind(ds.dpad.left, .dpadLeft)
        bind(ds.dpad.right, .dpadRight)
        bind(ds.buttonMenu, .options)
        bind(ds.buttonOptions, .create)
        bind(ds.buttonHome, .ps)
        bind(ds.touchpadButton, .touchpad)

        // Impede que o sistema "roube" esses botões (PS abre o Game Overlay, etc.).
        ds.buttonHome?.preferredSystemGestureState = .disabled
        ds.buttonMenu.preferredSystemGestureState = .disabled
        ds.buttonOptions?.preferredSystemGestureState = .disabled

        ds.touchpadPrimary.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated { self?.touchpadMoved(x: x, y: y) }
        }

        GCController.stopWirelessControllerDiscovery()
    }

    private func detach(_ c: GCController) {
        guard c === controller else { return }
        releaseEverything()
        controller = nil
        pad = nil
        updateInputActivity()
        controllerName = nil
        batteryText = nil
        pressedButtons.removeAll()
        controllerInput = .zero
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    private func updateBattery() {
        guard let b = controller?.battery else { batteryText = nil; return }
        let pct = Int((b.batteryLevel * 100).rounded())
        switch b.batteryState {
        case .charging: batteryText = "\(pct)% (\(AppLanguage.text("carregando")))"
        case .full: batteryText = "100%"
        default: batteryText = "\(pct)%"
        }
    }

    private func updateInputActivity() {
        let shouldStayResponsive = settings.enabled && pad != nil

        if shouldStayResponsive, inputActivity == nil {
            inputActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "DualPad processa entrada ativa do controle"
            )
        } else if !shouldStayResponsive, let inputActivity {
            ProcessInfo.processInfo.endActivity(inputActivity)
            self.inputActivity = nil
        }
    }

    private func bind(_ button: GCControllerButtonInput?, _ id: PadButton) {
        button?.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated { self?.buttonChanged(id, pressed: pressed) }
        }
    }

    // MARK: Botões

    private func buttonChanged(_ id: PadButton, pressed: Bool) {
        if pressed {
            pressedButtons.insert(id)
        } else {
            pressedButtons.remove(id)
        }
        lastButton = id
        lastButtonPressed = pressed
        lastPressed = "\(id.title) \(AppLanguage.text(pressed ? "pressionado" : "solto"))"
        guard settings.enabled, !isTestingController else { return }

        switch settings.action(for: id) {
        case .none:
            break
        case .leftClick:
            poster.setMouse(.left, down: pressed)
        case .rightClick:
            poster.setMouse(.right, down: pressed)
        case .middleClick:
            poster.setMouse(.middle, down: pressed)
        case .missionControl:
            if pressed { poster.showMissionControl() }
        case .key(let shortcut):
            poster.key(shortcut, down: pressed)
            if pressed {
                held[id] = Held(shortcut: shortcut,
                                nextRepeat: ProcessInfo.processInfo.systemUptime + repeatDelay)
            } else {
                held[id] = nil
            }
        }
    }

    // MARK: Touchpad

    private func touchpadMoved(x: Float, y: Float) {
        guard settings.enabled, !isTestingController, settings.touchpadMouse else { return }

        // (0, 0) significa "sem dedo" (ou dedo exatamente no centro).
        guard x != 0 || y != 0 else { lastTouch = nil; return }

        if let last = lastTouch {
            let k = settings.touchpadSensitivity / 2.0 // eixo vai de -1 a 1
            poster.moveCursor(dx: Double(x - last.x) * k,
                              dy: -Double(y - last.y) * k)
        }
        lastTouch = (x, y)
    }

    // MARK: Loop principal (sticks, scroll e repetição de teclas)

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.05)
        lastTick = now

        guard let ds = pad else {
            if controllerInput != .zero { controllerInput = .zero }
            return
        }

        if isTestingController, now - lastDiagnosticsUpdate >= 1.0 / 30.0 {
            lastDiagnosticsUpdate = now
            controllerInput = ControllerInputState(
                leftStickX: Double(ds.leftThumbstick.xAxis.value),
                leftStickY: Double(ds.leftThumbstick.yAxis.value),
                rightStickX: Double(ds.rightThumbstick.xAxis.value),
                rightStickY: Double(ds.rightThumbstick.yAxis.value),
                leftTrigger: Double(ds.leftTrigger.value),
                rightTrigger: Double(ds.rightTrigger.value)
            )
        }

        guard settings.enabled, !isTestingController else { return }

        // Stick esquerdo -> cursor
        let l = shaped(Double(ds.leftThumbstick.xAxis.value),
                       Double(ds.leftThumbstick.yAxis.value))
        poster.moveCursor(dx: l.x * settings.mouseSpeed * dt,
                          dy: -l.y * settings.mouseSpeed * dt)

        // Stick direito -> scroll
        let r = shaped(Double(ds.rightThumbstick.xAxis.value),
                       Double(ds.rightThumbstick.yAxis.value))
        let dir = settings.invertScroll ? -1.0 : 1.0
        poster.scroll(dx: -r.x * settings.scrollSpeed * dt * dir,
                      dy: r.y * settings.scrollSpeed * dt * dir)

        // Repetição de teclas seguradas
        for (id, h) in held where now >= h.nextRepeat {
            poster.key(h.shortcut, down: true, autorepeat: true)
            held[id]?.nextRepeat = now + repeatInterval
        }

        if now - lastBatteryCheck > 10 {
            lastBatteryCheck = now
            updateBattery()
        }
    }

    /// Zona morta radial + curva de aceleração.
    private func shaped(_ x: Double, _ y: Double) -> (x: Double, y: Double) {
        let m = hypot(x, y)
        let dz = settings.deadzone
        guard m > dz else { return (0, 0) }
        let n = min((m - dz) / (1 - dz), 1)
        let scale = pow(n, settings.acceleration)
        return (x / m * scale, y / m * scale)
    }

    // MARK: Limpeza e persistência

    private func releaseEverything() {
        for (_, h) in held { poster.key(h.shortcut, down: false) }
        held.removeAll()
        poster.releaseAll()
        lastTouch = nil
    }

    func resetMapping() {
        settings.mapping = PadSettings.defaultMapping
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }
}
