import Foundation
import AppKit
import Combine
import ApplicationServices
@preconcurrency import GameController

@MainActor
final class ControllerTestState {
    let buttons = ControllerButtonTestState()
    let analog = ControllerAnalogTestState()

    func setPressed(_ pressed: Bool, for button: PadButton) {
        buttons.setPressed(pressed, for: button)
    }

    func updateInput(_ newValue: ControllerInputState) {
        analog.updateInput(newValue)
    }

    func resetInput() {
        analog.reset()
    }

    func reset() {
        buttons.reset()
        analog.reset()
    }
}

@MainActor
final class ControllerButtonTestState: ObservableObject {
    @Published private(set) var pressedButtons: Set<PadButton> = []

    func setPressed(_ pressed: Bool, for button: PadButton) {
        if pressed {
            guard pressedButtons.insert(button).inserted else { return }
        } else {
            guard pressedButtons.remove(button) != nil else { return }
        }
    }

    func reset() {
        if !pressedButtons.isEmpty { pressedButtons.removeAll() }
    }
}

@MainActor
final class ControllerAnalogTestState: ObservableObject {
    @Published private(set) var input = ControllerInputState.zero

    func updateInput(_ newValue: ControllerInputState) {
        let rounded = ControllerInputState(
            leftStickX: newValue.leftStickX.roundedToHundredths,
            leftStickY: newValue.leftStickY.roundedToHundredths,
            rightStickX: newValue.rightStickX.roundedToHundredths,
            rightStickY: newValue.rightStickY.roundedToHundredths,
            leftTrigger: newValue.leftTrigger.roundedToHundredths,
            rightTrigger: newValue.rightTrigger.roundedToHundredths
        )
        guard input != rounded else { return }
        input = rounded
    }

    func reset() {
        guard input != .zero else { return }
        input = .zero
    }
}

struct ConnectedControllerOption: Identifiable, Equatable {
    let id: ObjectIdentifier
    let name: String
}

private extension Double {
    var roundedToHundredths: Double { (self * 100).rounded() / 100 }
}

@MainActor
final class ControllerManager: ObservableObject {

    // MARK: Estado exposto à interface

    @Published var controllerName: String?
    @Published var batteryText: String?
    @Published var batteryPercentage: Int?
    @Published private(set) var connectedControllers: [ConnectedControllerOption] = []
    @Published private(set) var selectedControllerID: ObjectIdentifier?
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var lastPressed = "—"
    let testState = ControllerTestState()
    @Published var isTestingController = false {
        didSet {
            if isTestingController && !oldValue {
                releaseEverything()
            } else if !isTestingController {
                testState.resetInput()
            }
            updateInputActivity()
            updateTimerFrequency()
        }
    }
    @Published var settings: PadSettings {
        didSet {
            save()
            if !settings.enabled { releaseEverything() }
            updateInputActivity()
            updateTimerFrequency()
        }
    }

    // MARK: Interno

    private let poster = EventPoster()
    private var controllers: [GCController] = []
    private var pad: GCDualSenseGamepad?
    private var controller: GCController?
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
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

        updateTimerFrequency()
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
        guard c.extendedGamepad is GCDualSenseGamepad else { return }
        guard !controllers.contains(where: { $0 === c }) else { return }
        controllers.append(c)
        refreshConnectedControllers()
        if controller == nil {
            selectController(ObjectIdentifier(c))
        }
    }

    func selectController(_ id: ObjectIdentifier) {
        guard let c = controllers.first(where: { ObjectIdentifier($0) == id }),
              let ds = c.extendedGamepad as? GCDualSenseGamepad,
              controller !== c else { return }

        releaseEverything()
        controller = c
        pad = ds
        selectedControllerID = id
        updateInputActivity()
        updateTimerFrequency()
        controllerName = connectedControllers.first(where: { $0.id == id })?.name ?? c.vendorName ?? "DualSense"
        updateBattery()

        bind(ds.buttonA, .cross, from: c)
        bind(ds.buttonB, .circle, from: c)
        bind(ds.buttonX, .square, from: c)
        bind(ds.buttonY, .triangle, from: c)
        bind(ds.leftShoulder, .l1, from: c)
        bind(ds.rightShoulder, .r1, from: c)
        bind(ds.leftTrigger, .l2, from: c)
        bind(ds.rightTrigger, .r2, from: c)
        bind(ds.leftThumbstickButton, .l3, from: c)
        bind(ds.rightThumbstickButton, .r3, from: c)
        bind(ds.dpad.up, .dpadUp, from: c)
        bind(ds.dpad.down, .dpadDown, from: c)
        bind(ds.dpad.left, .dpadLeft, from: c)
        bind(ds.dpad.right, .dpadRight, from: c)
        bind(ds.buttonMenu, .options, from: c)
        bind(ds.buttonOptions, .create, from: c)
        bind(ds.buttonHome, .ps, from: c)
        bind(ds.touchpadButton, .touchpad, from: c)

        // Impede que o sistema "roube" esses botões (PS abre o Game Overlay, etc.).
        ds.buttonHome?.preferredSystemGestureState = .disabled
        ds.buttonMenu.preferredSystemGestureState = .disabled
        ds.buttonOptions?.preferredSystemGestureState = .disabled

        ds.touchpadPrimary.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated {
                guard let self, self.controller === c else { return }
                self.touchpadMoved(x: x, y: y)
            }
        }
    }

    private func detach(_ c: GCController) {
        guard let index = controllers.firstIndex(where: { $0 === c }) else { return }
        let wasSelected = c === controller
        controllers.remove(at: index)
        refreshConnectedControllers()
        guard wasSelected else { return }

        releaseEverything()
        controller = nil
        pad = nil
        selectedControllerID = nil
        updateInputActivity()
        controllerName = nil
        batteryText = nil
        batteryPercentage = nil
        testState.reset()
        updateTimerFrequency()

        if let next = controllers.first {
            selectController(ObjectIdentifier(next))
        } else {
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }
    }

    private func refreshConnectedControllers() {
        var nameCounts: [String: Int] = [:]
        connectedControllers = controllers.map { connectedController in
            let baseName = connectedController.vendorName ?? "DualSense"
            nameCounts[baseName, default: 0] += 1
            let count = nameCounts[baseName, default: 1]
            let displayName = count == 1 ? baseName : "\(baseName) \(count)"
            return ConnectedControllerOption(id: ObjectIdentifier(connectedController), name: displayName)
        }
    }

    private func updateBattery() {
        guard let b = controller?.battery else {
            batteryText = nil
            batteryPercentage = nil
            return
        }
        let pct = Int((b.batteryLevel * 100).rounded())
        batteryPercentage = pct
        switch b.batteryState {
        case .charging: batteryText = "\(pct)% (\(AppLanguage.text("carregando")))"
        case .full: batteryText = "100%"
        default: batteryText = "\(pct)%"
        }
    }

    private func updateInputActivity() {
        let shouldStayResponsive = settings.enabled && pad != nil && !isTestingController

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

    private func bind(_ button: GCControllerButtonInput?, _ id: PadButton, from source: GCController) {
        button?.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated {
                guard self?.controller === source else { return }
                self?.buttonChanged(id, pressed: pressed)
            }
        }
    }

    // MARK: Botões

    private func buttonChanged(_ id: PadButton, pressed: Bool) {
        testState.setPressed(pressed, for: id)
        lastButton = id
        lastButtonPressed = pressed
        if !isTestingController {
            lastPressed = "\(id.title) \(AppLanguage.text(pressed ? "pressionado" : "solto"))"
        }
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
            testState.resetInput()
            return
        }

        if isTestingController {
            guard now - lastDiagnosticsUpdate >= 1.0 / 30.0 else { return }
            lastDiagnosticsUpdate = now
            testState.updateInput(ControllerInputState(
                leftStickX: Double(ds.leftThumbstick.xAxis.value),
                leftStickY: Double(ds.leftThumbstick.yAxis.value),
                rightStickX: Double(ds.rightThumbstick.xAxis.value),
                rightStickY: Double(ds.rightThumbstick.yAxis.value),
                leftTrigger: Double(ds.leftTrigger.value),
                rightTrigger: Double(ds.rightTrigger.value)
            ))
            if now - lastBatteryCheck > 10 {
                lastBatteryCheck = now
                updateBattery()
            }
            return
        }

        guard settings.enabled else { return }

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

    private func updateTimerFrequency() {
        let interval: TimeInterval
        if pad == nil || (!settings.enabled && !isTestingController) {
            interval = 1.0
        } else if isTestingController {
            interval = 1.0 / 30.0
        } else {
            interval = 1.0 / 120.0
        }

        guard interval != timerInterval else { return }
        timer?.invalidate()
        timerInterval = interval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
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
