import AppKit
import SwiftUI

@main
struct DualPadApp: App {
    @StateObject private var manager = ControllerManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(manager)
                .background(FixedWindowConfigurator())
        }
        .defaultSize(width: 1_400, height: 820)
        .windowStyle(.hiddenTitleBar)

        Settings {
            LanguageSettingsView()
        }
    }
}

private struct LanguageSettingsView: View {
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = "pt-BR"

    var body: some View {
        Form {
            Picker(AppLanguage.text("Idioma"), selection: $languageCode) {
                Text("Português (Brasil)").tag("pt-BR")
                Text("English (U.S.)").tag("en-US")
            }
        }
        .padding(20)
        .frame(width: 380, height: 92)
    }
}

private struct FixedWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowLockView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowLockView)?.configureWindow()
    }
}

@MainActor
private final class WindowLockView: NSView {
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    func configureWindow() {
        guard let window else { return }

        window.styleMask.remove(.resizable)
        window.styleMask.remove(.fullScreen)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.collectionBehavior.insert(.fullScreenDisallowsTiling)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        guard configuredWindow !== window else {
            window.contentMinSize = NSSize(width: 1_400, height: 820)
            window.contentMaxSize = NSSize(width: 1_400, height: 820)
            return
        }

        configuredWindow = window
        window.setContentSize(NSSize(width: 1_400, height: 820))
        window.contentMinSize = NSSize(width: 1_400, height: 820)
        window.contentMaxSize = NSSize(width: 1_400, height: 820)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
    }
}

@MainActor
private final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var manager: ControllerManager?
    private var openWindow: (() -> Void)?
    private var activeControlItem: NSMenuItem?

    private override init() {
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "DualPad")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        let openItem = NSMenuItem(title: AppLanguage.text("Abrir DualPad"), action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let activeItem = NSMenuItem(title: AppLanguage.text("Controle ativo"), action: #selector(toggleControl), keyEquivalent: "")
        activeItem.target = self
        menu.addItem(activeItem)
        activeControlItem = activeItem
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: AppLanguage.text("Sair do DualPad"), action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.isVisible = false
    }

    func configure(manager: ControllerManager, isVisible: Bool, openWindow: @escaping () -> Void) {
        self.manager = manager
        self.openWindow = openWindow
        statusItem.isVisible = isVisible
        updateControlItem()
    }

    func setVisible(_ isVisible: Bool) {
        statusItem.isVisible = isVisible
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshLanguage()
        updateControlItem()
    }

    func refreshLanguage() {
        guard let menu = statusItem.menu else { return }
        if menu.items.indices.contains(0) { menu.items[0].title = AppLanguage.text("Abrir DualPad") }
        if menu.items.indices.contains(2) { menu.items[2].title = AppLanguage.text("Controle ativo") }
        if menu.items.indices.contains(4) { menu.items[4].title = AppLanguage.text("Sair do DualPad") }
    }

    @objc private func openMainWindow() {
        _ = NSApp.setActivationPolicy(.regular)
        openWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleControl() {
        guard let manager else { return }
        manager.settings.enabled.toggle()
        updateControlItem()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateControlItem() {
        activeControlItem?.title = AppLanguage.text("Controle ativo")
        activeControlItem?.state = manager?.settings.enabled == true ? .on : .off
    }
}

private enum DualSenseImageAsset {
    static let image: NSImage? = {
        guard let imageURL = Bundle.main.url(forResource: "DualSenseController", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: imageURL)
    }()
}

struct ContentView: View {
    @EnvironmentObject private var pad: ControllerManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("dualpad.backgroundMode") private var backgroundMode = true
    @AppStorage(AppLanguage.preferenceKey) private var languageCode = "pt-BR"

    private let accent = Color.accentColor

    var body: some View {
        ZStack {
            background

            VStack(spacing: 20) {
                header

                HStack(alignment: .top, spacing: 18) {
                    leftColumn.frame(width: 350)
                    controllerCard.frame(width: 600, height: 480, alignment: .top)
                    rightColumn.frame(width: 350)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(24)
        }
        .frame(minWidth: 1_400, idealWidth: 1_400, minHeight: 820, idealHeight: 820)
        .windowResizeBehavior(.disabled)
        .onAppear {
            let isVisible = UserDefaults.standard.object(forKey: "dualpad.backgroundMode") as? Bool ?? true
            MenuBarController.shared.configure(manager: pad, isVisible: isVisible) {
                backgroundMode = false
                _ = NSApp.setActivationPolicy(.regular)
                openWindow(id: "main")
            }
            applyBackgroundMode(isVisible)
        }
        .onChange(of: languageCode) { _, _ in
            pad.refreshLocalizedStrings()
            MenuBarController.shared.refreshLanguage()
        }
        .onChange(of: backgroundMode) { _, isVisible in
            MenuBarController.shared.setVisible(isVisible)
            applyBackgroundMode(isVisible)
        }
    }

    private func applyBackgroundMode(_ isEnabled: Bool) {
        guard isEnabled else {
            _ = NSApp.setActivationPolicy(.regular)
            return
        }

        _ = NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            guard UserDefaults.standard.bool(forKey: "dualpad.backgroundMode"),
                  NSApp.activationPolicy() == .accessory else { return }
            NSApp.windows.first(where: { $0.isVisible && $0.title == "DualPad" })?.close()
        }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [accent.opacity(0.07), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 720
            )
            RadialGradient(
                colors: [Color.purple.opacity(0.035), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        brand
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brand: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .clipShape(.rect(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text("DualPad")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Seu DualSense, do seu jeito")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(pad.controllerName == nil ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(pad.controllerName ?? AppLanguage.text("Nenhum controle conectado"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(pad.batteryText.map { "\(AppLanguage.text("Bateria")) \($0)" } ?? (pad.controllerName == nil ? AppLanguage.text("Conecte via Bluetooth ou USB") : AppLanguage.text("Conectado")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundModeToggle: some View {
        HStack {
            Text(AppLanguage.text("Segundo plano"))
            Spacer()
            Toggle(AppLanguage.text("Segundo plano"), isOn: $backgroundMode)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize()
                .help(AppLanguage.text("Mantém o DualPad disponível pelo ícone na barra de menus."))
        }
        .frame(maxWidth: .infinity)
    }

    private var activationToggle: some View {
        HStack {
            Text(AppLanguage.text("Ativo"))
            Spacer()
            Toggle(AppLanguage.text("Ativo"), isOn: $pad.settings.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }

    private var controllerStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            connectionBadge
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                backgroundModeToggle
                activationToggle
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 16) {
            card(title: AppLanguage.text("MOVIMENTO"), subtitle: AppLanguage.text("Personalize o cursor")) {
                VStack(spacing: 15) {
                    settingSlider(AppLanguage.text("Velocidade"), value: $pad.settings.mouseSpeed, range: 300...3000, valueText: String(format: "%.0f px/s", pad.settings.mouseSpeed), icon: "cursorarrow")
                    settingSlider(AppLanguage.text("Zona morta"), value: $pad.settings.deadzone, range: 0.02...0.5, valueText: String(format: "%.2f", pad.settings.deadzone), icon: "circle.dashed")
                    settingSlider(AppLanguage.text("Aceleração"), value: $pad.settings.acceleration, range: 1...3, valueText: String(format: "%.1f×", pad.settings.acceleration), icon: "speedometer")
                }
            }

            card(title: "SCROLL", subtitle: AppLanguage.text("Stick direito")) {
                VStack(spacing: 12) {
                    settingSlider(AppLanguage.text("Velocidade"), value: $pad.settings.scrollSpeed, range: 200...3000, valueText: String(format: "%.0f px/s", pad.settings.scrollSpeed), icon: "arrow.up.and.down")
                    Toggle(AppLanguage.text("Inverter direção"), isOn: $pad.settings.invertScroll)
                        .toggleStyle(.switch)
                }
            }

            card(title: "TOUCHPAD", subtitle: AppLanguage.text("Gestos do DualSense")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(AppLanguage.text("Mover cursor"), isOn: $pad.settings.touchpadMouse)
                        .toggleStyle(.switch)
                    if pad.settings.touchpadMouse {
                        settingSlider(AppLanguage.text("Sensibilidade"), value: $pad.settings.touchpadSensitivity, range: 400...4000, valueText: String(format: "%.0f px", pad.settings.touchpadSensitivity), icon: "hand.draw")
                    }
                    Divider().overlay(Color.primary.opacity(0.1))
                    Text(AppLanguage.text("Clique do touchpad"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    actionPicker(for: .touchpad)
                }
            }

            accessibilityCard
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 16) {
            controllerStatusCard

            card(title: AppLanguage.text("BOTÕES"), subtitle: AppLanguage.text("Escolha o que cada botão faz")) {
                VStack(spacing: 3) {
                    mappingRow(.l2, symbol: "L2")
                    mappingRow(.l1, symbol: "L1")
                    mappingRow(.dpadUp, symbol: "arrow.up")
                    mappingRow(.dpadLeft, symbol: "arrow.left")
                    mappingRow(.dpadDown, symbol: "arrow.down")
                    mappingRow(.dpadRight, symbol: "arrow.right")
                    mappingRow(.l3, symbol: "l.joystick.press.down")
                    Divider().overlay(Color.primary.opacity(0.1)).padding(.vertical, 2)
                    mappingRow(.r2, symbol: "R2")
                    mappingRow(.r1, symbol: "R1")
                    mappingRow(.triangle, symbol: "triangle")
                    mappingRow(.circle, symbol: "circle")
                    mappingRow(.cross, symbol: "xmark")
                    mappingRow(.square, symbol: "square")
                    mappingRow(.r3, symbol: "r.joystick.press.down")
                    mappingRow(.options, symbol: "line.3.horizontal")
                    mappingRow(.create, symbol: "plus")
                    mappingRow(.ps, symbol: "playstation.logo")
                }

                Button(AppLanguage.text("Restaurar padrão")) {
                    pad.resetMapping()
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8)
            }
        }
    }

    private var controllerCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLanguage.text("MAPEAMENTO"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                    Text(AppLanguage.text("Visão geral do controle"))
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Toggle(AppLanguage.text("Testar controle"), isOn: $pad.isTestingController)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
            }

            if let controllerImage = DualSenseImageAsset.image {
                GeometryReader { proxy in
                    let imageSize = CGSize(width: proxy.size.width, height: proxy.size.width * 9 / 16)
                    ZStack {
                        Image(nsImage: controllerImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .shadow(color: .black.opacity(0.16), radius: 18, y: 10)

                        if pad.isTestingController {
                            ForEach(controllerHighlightButtons, id: \.self) { button in
                                ControllerButtonHighlight(button: button)
                                    .frame(
                                        width: imageSize.width * button.highlightSize.width,
                                        height: imageSize.height * button.highlightSize.height
                                    )
                                    .position(
                                        x: imageSize.width * button.highlightPosition.x,
                                        y: imageSize.height * button.highlightPosition.y
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.72)))
                            }
                            .animation(.easeOut(duration: 0.16), value: pad.pressedButtons)

                            stickPositionMarker(x: pad.controllerInput.leftStickX, y: pad.controllerInput.leftStickY)
                                .position(
                                    x: imageSize.width * 0.405 + pad.controllerInput.leftStickX * imageSize.width * 0.026,
                                    y: imageSize.height * 0.49 - pad.controllerInput.leftStickY * imageSize.height * 0.045
                                )
                            stickPositionMarker(x: pad.controllerInput.rightStickX, y: pad.controllerInput.rightStickY)
                                .position(
                                    x: imageSize.width * 0.595 + pad.controllerInput.rightStickX * imageSize.width * 0.026,
                                    y: imageSize.height * 0.49 - pad.controllerInput.rightStickY * imageSize.height * 0.045
                                )
                        }
                    }
                    .frame(width: imageSize.width, height: imageSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 560)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                ContentUnavailableView(
                    AppLanguage.text("Imagem do controle indisponível"),
                    systemImage: "gamecontroller",
                    description: Text(AppLanguage.text("DualSenseController.png não foi encontrada no app."))
                )
                .frame(maxWidth: 560)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }

            Group {
                if pad.isTestingController {
                    HStack(spacing: 12) {
                        diagnosticValue("L", x: pad.controllerInput.leftStickX, y: pad.controllerInput.leftStickY)
                        diagnosticValue("R", x: pad.controllerInput.rightStickX, y: pad.controllerInput.rightStickY)
                        Text("L2 \(pad.controllerInput.leftTrigger, format: .number.precision(.fractionLength(2)))")
                        Text("R2 \(pad.controllerInput.rightTrigger, format: .number.precision(.fractionLength(2)))")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(accent)
                        Text(AppLanguage.text("Altere qualquer ação pelos menus de cada botão."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: .capsule)
        }
        .padding(18)
        .frame(width: 600, height: 480, alignment: .top)
        .fixedSize(horizontal: true, vertical: true)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var controllerHighlightButtons: [PadButton] {
        PadButton.allCases.filter { pad.pressedButtons.contains($0) }
    }

    private func stickPositionMarker(x: Double, y: Double) -> some View {
        Circle()
            .fill(accent.opacity(hypot(x, y) > 0.04 ? 0.95 : 0.45))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: accent.opacity(0.8), radius: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func diagnosticValue(_ label: String, x: Double, y: Double) -> some View {
        Text("\(label) X \(x, format: .number.precision(.significantDigits(2))) Y \(y, format: .number.precision(.significantDigits(2)))")
    }

    private var accessibilityCard: some View {
        card(title: AppLanguage.text("ACESSIBILIDADE"), subtitle: pad.accessibilityGranted ? AppLanguage.text("Permissão concedida") : AppLanguage.text("Necessária para controlar o Mac")) {
            HStack(spacing: 10) {
                Image(systemName: pad.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(pad.accessibilityGranted ? .green : .orange)
                Text(pad.accessibilityGranted ? AppLanguage.text("Tudo pronto para usar.") : AppLanguage.text("Ative o DualPad nos Ajustes do Sistema."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !pad.accessibilityGranted {
                HStack {
                    Button(AppLanguage.text("Pedir")) { pad.requestAccessibility() }
                        .buttonStyle(.glass)
                    Button(AppLanguage.text("Abrir Ajustes")) { pad.openAccessibilitySettings() }
                        .buttonStyle(.glass)
                }
            }
        }
    }

    private func card<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(accent)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private func settingSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
                    .frame(width: 16)
                Text(title)
                    .font(.caption)
                Spacer(minLength: 4)
                Text(valueText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(accent)
        }
    }

    private func mappingRow(_ button: PadButton, symbol: String) -> some View {
        HStack(spacing: 8) {
            Group {
                if ["L1", "R1", "L2", "R2"].contains(symbol) {
                    Text(symbol)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .frame(width: 14, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(accent, lineWidth: 0.9))
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(accent)
            .frame(width: 17, height: 17)
            Text(button.title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            actionPicker(for: button)
                .frame(width: 132)
        }
    }

    private func actionPicker(for button: PadButton) -> some View {
        Picker(button.title, selection: Binding(
            get: { pad.settings.action(for: button) },
            set: { pad.settings.mapping[button.rawValue] = $0 }
        )) {
            ForEach(PadAction.all, id: \.self) { action in
                Text(action.title).tag(action)
            }
        }
        .labelsHidden()
        .controlSize(.small)
        .id(languageCode)
    }
}

private struct ControllerButtonHighlight: View {
    let button: PadButton

    private let playStationBlue = Color(red: 0.0, green: 0.44, blue: 0.84)

    var body: some View {
        GeometryReader { proxy in
            let outline = button.highlightPath(in: CGRect(origin: .zero, size: proxy.size))

            ZStack {
                outline
                    .fill(playStationBlue.opacity(0.24))
                outline
                    .stroke(playStationBlue, lineWidth: 1)
                    .shadow(color: playStationBlue.opacity(0.7), radius: 3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension PadButton {
    func highlightPath(in rect: CGRect) -> Path {
        switch self {
        case .cross, .circle, .square, .triangle, .l3, .r3:
            return Path(ellipseIn: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04))
        case .l1:
            return shoulderBumperPath(in: rect, isLeft: true)
        case .l2:
            return shoulderButtonPath(in: rect, isLeft: true)
        case .r1:
            return shoulderBumperPath(in: rect, isLeft: false)
        case .r2:
            return shoulderButtonPath(in: rect, isLeft: false)
        case .dpadUp:
            return dpadVerticalKeyPath(in: rect, pointsDown: false)
        case .dpadDown:
            return dpadVerticalKeyPath(in: rect, pointsDown: true)
        case .dpadLeft:
            return dpadSideKeyPath(in: rect, pointsRight: false)
        case .dpadRight:
            return dpadSideKeyPath(in: rect, pointsRight: true)
        case .options, .create:
            var path = Path()
            path.addRoundedRect(in: rect.insetBy(dx: 1, dy: 1), cornerSize: CGSize(width: rect.width * 0.22, height: rect.height * 0.22))
            return path
        case .ps:
            return Path(ellipseIn: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        case .touchpad:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.035, y: rect.minY + rect.height * 0.18))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.minY + rect.height * 0.025),
                control: CGPoint(x: rect.minX + rect.width * 0.045, y: rect.minY + rect.height * 0.025)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.87, y: rect.minY + rect.height * 0.025),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.015)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.965, y: rect.minY + rect.height * 0.18),
                control: CGPoint(x: rect.maxX - rect.width * 0.045, y: rect.minY + rect.height * 0.025)
            )
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.82))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.maxY - rect.height * 0.025),
                control: CGPoint(x: rect.maxX - rect.width * 0.045, y: rect.maxY - rect.height * 0.025)
            )
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.025))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.09, y: rect.minY + rect.height * 0.82),
                control: CGPoint(x: rect.minX + rect.width * 0.045, y: rect.maxY - rect.height * 0.025)
            )
            path.closeSubpath()
            return path
        }
    }

    private func shoulderButtonCapPath(in rect: CGRect) -> Path {
        Path(roundedRect: rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.08),
             cornerSize: CGSize(width: rect.width * 0.28, height: rect.width * 0.28))
    }

    private func shoulderBumperPath(in rect: CGRect, isLeft: Bool) -> Path {
        // Follow the slanted, softly rounded front edge of each L1/R1 bumper.
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let localX = isLeft ? x : 1 - x
            return CGPoint(x: rect.minX + localX * rect.width,
                           y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.025, 0.76))
        path.addQuadCurve(to: point(0.20, 0.35), control: point(0.035, 0.45))
        path.addLine(to: point(0.79, 0.035))
        path.addQuadCurve(to: point(0.97, 0.24), control: point(0.95, 0.025))
        path.addLine(to: point(0.98, 0.69))
        path.addQuadCurve(to: point(0.84, 0.91), control: point(0.98, 0.88))
        path.addLine(to: point(0.18, 0.98))
        path.addQuadCurve(to: point(0.025, 0.76), control: point(0.02, 0.96))
        path.closeSubpath()
        return path
    }

    private func shoulderButtonPath(in rect: CGRect, isLeft: Bool) -> Path {
        let points: [CGPoint] = isLeft
            ? [
                CGPoint(x: 0.04, y: 0.72), CGPoint(x: 0.76, y: 0.08),
                CGPoint(x: 0.96, y: 0.28), CGPoint(x: 0.98, y: 0.82),
                CGPoint(x: 0.18, y: 0.98)
            ]
            : [
                CGPoint(x: 0.24, y: 0.08), CGPoint(x: 0.96, y: 0.72),
                CGPoint(x: 0.82, y: 0.98), CGPoint(x: 0.02, y: 0.82),
                CGPoint(x: 0.04, y: 0.28)
            ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }

    private func dpadVerticalKeyPath(in rect: CGRect, pointsDown: Bool) -> Path {
        // The vertical D-pad caps mirror the side caps and taper into the hub.
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let localY = pointsDown ? 1 - y : y
            return CGPoint(x: rect.minX + x * rect.width,
                           y: rect.minY + localY * rect.height)
        }

        var path = Path()
        path.move(to: point(0.50, 0.965))
        path.addQuadCurve(to: point(0.82, 0.76), control: point(0.66, 0.96))
        path.addLine(to: point(0.95, 0.28))
        path.addQuadCurve(to: point(0.78, 0.055), control: point(0.98, 0.08))
        path.addLine(to: point(0.22, 0.055))
        path.addQuadCurve(to: point(0.05, 0.28), control: point(0.02, 0.08))
        path.addLine(to: point(0.18, 0.76))
        path.addQuadCurve(to: point(0.50, 0.965), control: point(0.34, 0.96))
        path.closeSubpath()
        return path
    }

    private func dpadSideKeyPath(in rect: CGRect, pointsRight: Bool) -> Path {
        // Match the DualSense side caps: rounded outer edge, narrowing toward
        // the shared center of the cross. Mirror one path for both directions.
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let localX = pointsRight ? 1 - x : x
            return CGPoint(x: rect.minX + localX * rect.width,
                           y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0.035, 0.50))
        path.addQuadCurve(to: point(0.27, 0.08), control: point(0.025, 0.18))
        path.addQuadCurve(to: point(0.58, 0.08), control: point(0.42, 0.025))
        path.addLine(to: point(0.93, 0.37))
        path.addQuadCurve(to: point(0.93, 0.63), control: point(1.015, 0.50))
        path.addLine(to: point(0.58, 0.92))
        path.addQuadCurve(to: point(0.27, 0.92), control: point(0.42, 0.975))
        path.addQuadCurve(to: point(0.035, 0.50), control: point(0.025, 0.82))
        path.closeSubpath()
        return path
    }

    var highlightPosition: CGPoint {
        switch self {
        case .l1: CGPoint(x: 0.319, y: 0.183)
        case .r1: CGPoint(x: 0.681, y: 0.183)
        case .l2: CGPoint(x: 0.300, y: 0.162)
        case .r2: CGPoint(x: 0.700, y: 0.162)
        case .dpadUp: CGPoint(x: 0.315, y: 0.298)
        case .dpadDown: CGPoint(x: 0.315, y: 0.405)
        case .dpadLeft: CGPoint(x: 0.286, y: 0.351)
        case .dpadRight: CGPoint(x: 0.344, y: 0.351)
        case .triangle: CGPoint(x: 0.686, y: 0.275)
        case .square: CGPoint(x: 0.642, y: 0.350)
        case .circle: CGPoint(x: 0.729, y: 0.350)
        case .cross: CGPoint(x: 0.687, y: 0.426)
        case .l3: CGPoint(x: 0.405, y: 0.49)
        case .r3: CGPoint(x: 0.595, y: 0.49)
        case .options: CGPoint(x: 0.638, y: 0.235)
        case .create: CGPoint(x: 0.362, y: 0.235)
        case .ps: CGPoint(x: 0.5, y: 0.483)
        case .touchpad: CGPoint(x: 0.5, y: 0.278)
        }
    }

    var highlightSize: CGSize {
        switch self {
        case .l2, .r2:
            CGSize(width: 0.065, height: 0.045)
        case .l1, .r1:
            CGSize(width: 0.078, height: 0.030)
        case .options, .create:
            CGSize(width: 0.018, height: 0.05)
        case .dpadUp, .dpadDown:
            CGSize(width: 0.043, height: 0.077)
        case .dpadLeft, .dpadRight:
            CGSize(width: 0.052, height: 0.068)
        case .triangle, .square, .circle, .cross:
            CGSize(width: 0.04, height: 0.072)
        case .l3, .r3:
            CGSize(width: 0.085, height: 0.15)
        case .ps:
            CGSize(width: 0.042, height: 0.065)
        case .touchpad:
            CGSize(width: 0.255, height: 0.245)
        }
    }
}

private struct DualSenseIllustration: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Ellipse()
                    .fill(accent.opacity(0.13))
                    .frame(width: width * 0.78, height: height * 0.70)
                    .blur(radius: 45)

                ControllerBody()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.93, blue: 1.0),
                                Color(red: 0.55, green: 0.69, blue: 0.86),
                                Color(red: 0.34, green: 0.47, blue: 0.66)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        ControllerBody()
                            .stroke(.white.opacity(0.72), lineWidth: 1.5)
                    }
                    .frame(width: width * 0.90, height: height * 0.72)
                    .shadow(color: .black.opacity(0.34), radius: 26, y: 22)

                controllerDetails(width: width, height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func controllerDetails(width: CGFloat, height: CGFloat) -> some View {
        let scale = min(width / 540, height / 360)

        return ZStack {
            // Touchpad and center controls
            RoundedRectangle(cornerRadius: 9 * scale)
                .fill(Color(red: 0.13, green: 0.18, blue: 0.27))
                .frame(width: 88 * scale, height: 49 * scale)
                .overlay {
                    RoundedRectangle(cornerRadius: 9 * scale)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .offset(y: -30 * scale)

            Capsule()
                .fill(accent.opacity(0.85))
                .frame(width: 32 * scale, height: 3 * scale)
                .offset(y: 5 * scale)

            // D-pad
            dpad(scale: scale)
                .offset(x: -112 * scale, y: -22 * scale)

            // Face buttons
            faceButton("triangle", scale: scale, x: 111, y: -52)
            faceButton("circle", scale: scale, x: 134, y: -28)
            faceButton("xmark", scale: scale, x: 111, y: -4)
            faceButton("square", scale: scale, x: 88, y: -28)

            // Analog sticks
            stick(scale: scale)
                .offset(x: -58 * scale, y: 39 * scale)
            stick(scale: scale)
                .offset(x: 58 * scale, y: 39 * scale)

            // Shoulder accents and light bar
            RoundedRectangle(cornerRadius: 5 * scale)
                .fill(.white.opacity(0.55))
                .frame(width: 86 * scale, height: 12 * scale)
                .rotationEffect(.degrees(-13))
                .offset(x: -155 * scale, y: -103 * scale)
            RoundedRectangle(cornerRadius: 5 * scale)
                .fill(.white.opacity(0.55))
                .frame(width: 86 * scale, height: 12 * scale)
                .rotationEffect(.degrees(13))
                .offset(x: 155 * scale, y: -103 * scale)

            // Small status indicators
            HStack(spacing: 5 * scale) {
                ForEach(0..<3) { _ in
                    Circle().fill(accent.opacity(0.8)).frame(width: 4 * scale, height: 4 * scale)
                }
            }
            .offset(y: 5 * scale)
        }
        .frame(width: width, height: height)
    }

    private func dpad(scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4 * scale)
                .fill(Color(red: 0.16, green: 0.21, blue: 0.30))
                .frame(width: 19 * scale, height: 57 * scale)
            RoundedRectangle(cornerRadius: 4 * scale)
                .fill(Color(red: 0.16, green: 0.21, blue: 0.30))
                .frame(width: 57 * scale, height: 19 * scale)
        }
    }

    private func faceButton(_ symbol: String, scale: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11 * scale, weight: .bold))
            .foregroundStyle(accent.opacity(0.95))
            .frame(width: 23 * scale, height: 23 * scale)
            .background(Color(red: 0.15, green: 0.20, blue: 0.29), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.17), lineWidth: 1))
            .offset(x: x * scale, y: y * scale)
    }

    private func stick(scale: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.23, green: 0.29, blue: 0.39), Color(red: 0.08, green: 0.12, blue: 0.19)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 39 * scale, height: 39 * scale)
            .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1.4))
            .overlay(Circle().fill(.white.opacity(0.07)).padding(5 * scale))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
    }
}

private struct ControllerBody: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.29, y: h * 0.10))
        path.addCurve(to: CGPoint(x: w * 0.39, y: h * 0.08), control1: CGPoint(x: w * 0.32, y: h * 0.05), control2: CGPoint(x: w * 0.36, y: h * 0.06))
        path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.08))
        path.addCurve(to: CGPoint(x: w * 0.71, y: h * 0.10), control1: CGPoint(x: w * 0.64, y: h * 0.06), control2: CGPoint(x: w * 0.68, y: h * 0.05))
        path.addCurve(to: CGPoint(x: w * 0.87, y: h * 0.27), control1: CGPoint(x: w * 0.78, y: h * 0.12), control2: CGPoint(x: w * 0.83, y: h * 0.18))
        path.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.76), control1: CGPoint(x: w * 0.94, y: h * 0.37), control2: CGPoint(x: w * 0.99, y: h * 0.63))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.88), control1: CGPoint(x: w * 0.94, y: h * 0.91), control2: CGPoint(x: w * 0.90, y: h * 0.93))
        path.addCurve(to: CGPoint(x: w * 0.77, y: h * 0.81), control1: CGPoint(x: w * 0.85, y: h * 0.84), control2: CGPoint(x: w * 0.81, y: h * 0.83))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.62))
        path.addCurve(to: CGPoint(x: w * 0.59, y: h * 0.57), control1: CGPoint(x: w * 0.65, y: h * 0.59), control2: CGPoint(x: w * 0.62, y: h * 0.57))
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.57))
        path.addCurve(to: CGPoint(x: w * 0.32, y: h * 0.62), control1: CGPoint(x: w * 0.38, y: h * 0.57), control2: CGPoint(x: w * 0.35, y: h * 0.59))
        path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.81))
        path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.88), control1: CGPoint(x: w * 0.19, y: h * 0.83), control2: CGPoint(x: w * 0.15, y: h * 0.84))
        path.addCurve(to: CGPoint(x: w * 0.04, y: h * 0.76), control1: CGPoint(x: w * 0.10, y: h * 0.93), control2: CGPoint(x: w * 0.06, y: h * 0.91))
        path.addCurve(to: CGPoint(x: w * 0.13, y: h * 0.27), control1: CGPoint(x: w * 0.01, y: h * 0.63), control2: CGPoint(x: w * 0.06, y: h * 0.37))
        path.addCurve(to: CGPoint(x: w * 0.29, y: h * 0.10), control1: CGPoint(x: w * 0.17, y: h * 0.18), control2: CGPoint(x: w * 0.22, y: h * 0.12))
        path.closeSubpath()
        return path
    }
}
