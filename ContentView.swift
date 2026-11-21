import AppKit
import SwiftUI

@main
struct DualPadApp: App {
    @StateObject private var manager = ControllerManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(manager)
        }
        .defaultSize(width: 1_350, height: 900)
        .windowResizability(.automatic)
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

        let openItem = NSMenuItem(title: "Abrir DualPad", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let activeItem = NSMenuItem(title: "Controle ativo", action: #selector(toggleControl), keyEquivalent: "")
        activeItem.target = self
        menu.addItem(activeItem)
        activeControlItem = activeItem
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Sair do DualPad", action: #selector(quit), keyEquivalent: "")
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
        updateControlItem()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow?()
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
        activeControlItem?.state = manager?.settings.enabled == true ? .on : .off
    }
}

struct ContentView: View {
    @EnvironmentObject private var pad: ControllerManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("dualpad.backgroundMode") private var backgroundMode = true

    private let accent = Color.accentColor

    var body: some View {
        ZStack {
            background

            VStack(spacing: 20) {
                header

                HStack(alignment: .top, spacing: 18) {
                    leftColumn.frame(width: 250)
                    controllerCard.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    rightColumn.frame(width: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(24)
        }
        .frame(minWidth: 1_180, idealWidth: 1_350, minHeight: 820, idealHeight: 900)
        .onAppear {
            let isVisible = UserDefaults.standard.object(forKey: "dualpad.backgroundMode") as? Bool ?? true
            MenuBarController.shared.configure(manager: pad, isVisible: isVisible) {
                openWindow(id: "main")
            }
        }
        .onChange(of: backgroundMode) { _, isVisible in
            MenuBarController.shared.setVisible(isVisible)
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                brand
                Spacer(minLength: 12)
                connectionBadge
                backgroundModeToggle
                activationToggle
            }

            VStack(alignment: .leading, spacing: 14) {
                brand
                HStack(spacing: 10) {
                    connectionBadge
                    Spacer(minLength: 0)
                    backgroundModeToggle
                    activationToggle
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brand: some View {
        HStack(spacing: 14) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .glassEffect(.regular.tint(accent.opacity(0.14)), in: .rect(cornerRadius: 15))

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
                Text(pad.controllerName ?? "Nenhum controle conectado")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(pad.batteryText.map { "Bateria \($0)" } ?? (pad.controllerName == nil ? "Conecte via Bluetooth ou USB" : "Conectado"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .fixedSize(horizontal: true, vertical: false)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    private var backgroundModeToggle: some View {
        Toggle("Segundo plano", isOn: $backgroundMode)
            .toggleStyle(.switch)
            .fixedSize()
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .capsule)
            .help("Mantém o DualPad disponível pelo ícone na barra de menus.")
    }

    private var activationToggle: some View {
        Toggle("Ativo", isOn: $pad.settings.enabled)
            .toggleStyle(.switch)
            .fixedSize()
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .capsule)
    }

    private var leftColumn: some View {
        VStack(spacing: 16) {
            card(title: "MOVIMENTO", subtitle: "Personalize o cursor") {
                VStack(spacing: 15) {
                    settingSlider("Velocidade", value: $pad.settings.mouseSpeed, range: 300...3000, valueText: String(format: "%.0f px/s", pad.settings.mouseSpeed), icon: "cursorarrow")
                    settingSlider("Zona morta", value: $pad.settings.deadzone, range: 0.02...0.5, valueText: String(format: "%.2f", pad.settings.deadzone), icon: "circle.dashed")
                    settingSlider("Aceleração", value: $pad.settings.acceleration, range: 1...3, valueText: String(format: "%.1f×", pad.settings.acceleration), icon: "speedometer")
                }
            }

            card(title: "TOUCHPAD", subtitle: "Gestos do DualSense") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Mover cursor", isOn: $pad.settings.touchpadMouse)
                        .toggleStyle(.switch)
                    if pad.settings.touchpadMouse {
                        settingSlider("Sensibilidade", value: $pad.settings.touchpadSensitivity, range: 400...4000, valueText: String(format: "%.0f px", pad.settings.touchpadSensitivity), icon: "hand.draw")
                    }
                    Divider().overlay(Color.primary.opacity(0.1))
                    Text("Clique do touchpad")
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
            card(title: "SCROLL", subtitle: "Stick direito") {
                VStack(spacing: 12) {
                    settingSlider("Velocidade", value: $pad.settings.scrollSpeed, range: 200...3000, valueText: String(format: "%.0f px/s", pad.settings.scrollSpeed), icon: "arrow.up.and.down")
                    Toggle("Inverter direção", isOn: $pad.settings.invertScroll)
                        .toggleStyle(.switch)
                }
            }

            card(title: "BOTÕES", subtitle: "Escolha o que cada botão faz") {
                VStack(spacing: 3) {
                    mappingRow(.l2, symbol: "l2.button.roundedtop.horizontal")
                    mappingRow(.l1, symbol: "l1.button.roundedtop.horizontal")
                    mappingRow(.dpadUp, symbol: "arrow.up")
                    mappingRow(.dpadLeft, symbol: "arrow.left")
                    mappingRow(.dpadDown, symbol: "arrow.down")
                    mappingRow(.dpadRight, symbol: "arrow.right")
                    mappingRow(.l3, symbol: "l.joystick.press.down")
                    Divider().overlay(Color.primary.opacity(0.1)).padding(.vertical, 2)
                    mappingRow(.r2, symbol: "r2.button.roundedtop.horizontal")
                    mappingRow(.r1, symbol: "r1.button.roundedtop.horizontal")
                    mappingRow(.triangle, symbol: "triangle")
                    mappingRow(.circle, symbol: "circle")
                    mappingRow(.cross, symbol: "xmark")
                    mappingRow(.square, symbol: "square")
                    mappingRow(.r3, symbol: "r.joystick.press.down")
                    mappingRow(.options, symbol: "line.3.horizontal")
                    mappingRow(.create, symbol: "plus")
                    mappingRow(.ps, symbol: "playstation.logo")
                }

                Button("Restaurar padrão") {
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
                    Text("MAPEAMENTO")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                    Text("Visão geral do controle")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Text(pad.lastPressed == "—" ? "Aguardando botão" : pad.lastPressed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: .capsule)
            }

            if let imageURL = Bundle.main.url(forResource: "DualSenseController", withExtension: "png"),
               let controllerImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: controllerImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 560)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
            } else {
                ContentUnavailableView(
                    "Imagem do controle indisponível",
                    systemImage: "gamecontroller",
                    description: Text("DualSenseController.png não foi encontrada no app.")
                )
                .frame(maxWidth: 560)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(accent)
                Text("Altere qualquer ação pelos menus de cada botão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: .capsule)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var accessibilityCard: some View {
        card(title: "ACESSIBILIDADE", subtitle: pad.accessibilityGranted ? "Permissão concedida" : "Necessária para controlar o Mac") {
            HStack(spacing: 10) {
                Image(systemName: pad.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(pad.accessibilityGranted ? .green : .orange)
                Text(pad.accessibilityGranted ? "Tudo pronto para usar." : "Ative o DualPad nos Ajustes do Sistema.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !pad.accessibilityGranted {
                HStack {
                    Button("Pedir") { pad.requestAccessibility() }
                        .buttonStyle(.glass)
                    Button("Abrir Ajustes") { pad.openAccessibilitySettings() }
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
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 17)
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
