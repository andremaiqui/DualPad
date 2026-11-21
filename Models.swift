import Foundation
import CoreGraphics

enum AppLanguage {
    static let preferenceKey = "dualpad.language"

    static var isEnglish: Bool {
        UserDefaults.standard.string(forKey: preferenceKey) == "en-US"
    }

    static func text(_ portuguese: String) -> String {
        guard isEnglish else { return portuguese }
        return translations[portuguese] ?? portuguese
    }

    static func shortcutLabel(_ label: String) -> String {
        guard isEnglish else { return label }
        let labels = [
            "Espaço": "Space",
            "Seta ↑": "Up Arrow",
            "Seta ↓": "Down Arrow",
            "Seta ←": "Left Arrow",
            "Seta →": "Right Arrow",
            "⌘W (fechar janela)": "⌘W (Close Window)",
            "⌘C (copiar)": "⌘C (Copy)",
            "⌘V (colar)": "⌘V (Paste)",
            "⌘Z (desfazer)": "⌘Z (Undo)",
            "⌘[ (voltar)": "⌘[ (Back)",
            "⌘] (avançar)": "⌘] (Forward)",
            "⌘Espaço (Spotlight)": "⌘Space (Spotlight)"
        ]
        return labels[label] ?? label
    }

    private static let translations: [String: String] = [
        "Seu DualSense, do seu jeito": "Your DualSense, your way",
        "Nenhum controle conectado": "No controller connected",
        "Bateria": "Battery",
        "Conecte via Bluetooth ou USB": "Connect via Bluetooth or USB",
        "Conectado": "Connected",
        "Segundo plano": "Background",
        "Mantém o DualPad disponível pelo ícone na barra de menus.": "Keeps DualPad available from the menu bar icon.",
        "Ativo": "Enabled",
        "MOVIMENTO": "MOTION",
        "Personalize o cursor": "Customize the cursor",
        "Velocidade": "Speed",
        "Zona morta": "Dead zone",
        "Aceleração": "Acceleration",
        "Stick direito": "Right stick",
        "Inverter direção": "Invert direction",
        "TOUCHPAD": "TOUCHPAD",
        "Gestos do DualSense": "DualSense Gestures",
        "Mover cursor": "Move cursor",
        "Sensibilidade": "Sensitivity",
        "Clique do touchpad": "Touchpad click",
        "BOTÕES": "BUTTONS",
        "Escolha o que cada botão faz": "Choose what each button does",
        "Restaurar padrão": "Restore defaults",
        "MAPEAMENTO": "MAPPING",
        "Visão geral do controle": "Controller overview",
        "Aguardando botão": "Waiting for button",
        "Imagem do controle indisponível": "Controller image unavailable",
        "DualSenseController.png não foi encontrada no app.": "DualSenseController.png could not be found in the app.",
        "Altere qualquer ação pelos menus de cada botão.": "Change any action using the menu for each button.",
        "ACESSIBILIDADE": "ACCESSIBILITY",
        "Permissão concedida": "Permission granted",
        "Necessária para controlar o Mac": "Required to control your Mac",
        "Tudo pronto para usar.": "You’re all set.",
        "Ative o DualPad nos Ajustes do Sistema.": "Enable DualPad in System Settings.",
        "Pedir": "Request",
        "Abrir Ajustes": "Open Settings",
        "L3 (clique do stick esquerdo)": "L3 (Left Stick Click)",
        "R3 (clique do stick direito)": "R3 (Right Stick Click)",
        "Botão PS": "PS Button",
        "Nada": "None",
        "Clique esquerdo": "Left click",
        "Clique direito": "Right click",
        "Clique do meio": "Middle click",
        "Tecla:": "Key:",
        "pressionado": "pressed",
        "solto": "released",
        "carregando": "charging",
        "Abrir DualPad": "Open DualPad",
        "Controle ativo": "Controller enabled",
        "Sair do DualPad": "Quit DualPad",
        "Idioma": "Language"
    ]
}

// MARK: - Botões do DualSense

enum PadButton: String, CaseIterable, Codable, Identifiable {
    case cross, circle, square, triangle
    case l1, r1, l2, r2, l3, r3
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case options, create, ps, touchpad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cross: return "✕ Cross"
        case .circle: return "○ Circle"
        case .square: return "□ Square"
        case .triangle: return "△ Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return AppLanguage.text("L3 (clique do stick esquerdo)")
        case .r3: return AppLanguage.text("R3 (clique do stick direito)")
        case .dpadUp: return "D-pad ↑"
        case .dpadDown: return "D-pad ↓"
        case .dpadLeft: return "D-pad ←"
        case .dpadRight: return "D-pad →"
        case .options: return "Options"
        case .create: return "Create"
        case .ps: return AppLanguage.text("Botão PS")
        case .touchpad: return AppLanguage.text("Clique do touchpad")
        }
    }
}

// MARK: - Atalhos de teclado

struct Shortcut: Codable, Hashable {
    var label: String
    var keyCode: UInt16
    var flagsRaw: UInt64

    var flags: CGEventFlags { CGEventFlags(rawValue: flagsRaw) }

    var displayLabel: String { AppLanguage.shortcutLabel(label) }

    private static let cmd = CGEventFlags.maskCommand.rawValue
    private static let ctrl = CGEventFlags.maskControl.rawValue

    /// Códigos de tecla virtuais do macOS (teclado ANSI).
    static let presets: [Shortcut] = [
        Shortcut(label: "Return", keyCode: 36, flagsRaw: 0),
        Shortcut(label: "Escape", keyCode: 53, flagsRaw: 0),
        Shortcut(label: "Espaço", keyCode: 49, flagsRaw: 0),
        Shortcut(label: "Tab", keyCode: 48, flagsRaw: 0),
        Shortcut(label: "Delete", keyCode: 51, flagsRaw: 0),
        Shortcut(label: "Seta ↑", keyCode: 126, flagsRaw: 0),
        Shortcut(label: "Seta ↓", keyCode: 125, flagsRaw: 0),
        Shortcut(label: "Seta ←", keyCode: 123, flagsRaw: 0),
        Shortcut(label: "Seta →", keyCode: 124, flagsRaw: 0),
        Shortcut(label: "Page Up", keyCode: 116, flagsRaw: 0),
        Shortcut(label: "Page Down", keyCode: 121, flagsRaw: 0),
        Shortcut(label: "⌘W (fechar janela)", keyCode: 13, flagsRaw: cmd),
        Shortcut(label: "⌘C (copiar)", keyCode: 8, flagsRaw: cmd),
        Shortcut(label: "⌘V (colar)", keyCode: 9, flagsRaw: cmd),
        Shortcut(label: "⌘Z (desfazer)", keyCode: 6, flagsRaw: cmd),
        Shortcut(label: "⌘[ (voltar)", keyCode: 33, flagsRaw: cmd),
        Shortcut(label: "⌘] (avançar)", keyCode: 30, flagsRaw: cmd),
        Shortcut(label: "⌘Espaço (Spotlight)", keyCode: 49, flagsRaw: cmd),
        missionControl,
    ]

    static let missionControl = Shortcut(label: "⌃↑ (Mission Control)", keyCode: 126, flagsRaw: ctrl)
}

// MARK: - Ações

enum PadAction: Codable, Hashable {
    case none
    case leftClick
    case rightClick
    case middleClick
    case missionControl
    case key(Shortcut)

    var title: String {
        switch self {
        case .none: return AppLanguage.text("Nada")
        case .leftClick: return AppLanguage.text("Clique esquerdo")
        case .rightClick: return AppLanguage.text("Clique direito")
        case .middleClick: return AppLanguage.text("Clique do meio")
        case .missionControl: return "Mission Control"
        case .key(let s):
            let prefix = AppLanguage.text("Tecla:")
            return "\(prefix) \(s.displayLabel)"
        }
    }

    static let all: [PadAction] =
        [.none, .leftClick, .rightClick, .middleClick, .missionControl] + Shortcut.presets
            .filter { $0 != Shortcut.missionControl }
            .map { .key($0) }
}

// MARK: - Configurações

struct PadSettings: Codable {
    var enabled = true

    // Stick esquerdo -> cursor
    var mouseSpeed = 1100.0        // pixels/segundo com o stick no máximo
    var deadzone = 0.15            // 0...0.5
    var acceleration = 1.7         // expoente da curva (1 = linear)

    // Stick direito -> scroll
    var scrollSpeed = 900.0
    var invertScroll = false

    // Touchpad -> cursor
    var touchpadMouse = true
    var touchpadSensitivity = 1400.0 // pixels para atravessar o touchpad inteiro

    // Nome do botão (rawValue) -> ação
    var mapping: [String: PadAction] = PadSettings.defaultMapping

    func action(for button: PadButton) -> PadAction {
        mapping[button.rawValue] ?? .none
    }

    static var defaultMapping: [String: PadAction] {
        func key(_ label: String) -> PadAction {
            guard let shortcut = Shortcut.presets.first(where: { $0.label == label }) else {
                return .none
            }
            return .key(shortcut)
        }
        return [
            PadButton.cross.rawValue: .leftClick,
            PadButton.circle.rawValue: key("Escape"),
            PadButton.square.rawValue: .rightClick,
            PadButton.triangle.rawValue: key("Return"),
            PadButton.l1.rawValue: key("⌘[ (voltar)"),
            PadButton.r1.rawValue: key("⌘] (avançar)"),
            PadButton.l2.rawValue: .rightClick,
            PadButton.r2.rawValue: .leftClick,
            PadButton.l3.rawValue: .none,
            PadButton.r3.rawValue: .middleClick,
            PadButton.dpadUp.rawValue: key("Seta ↑"),
            PadButton.dpadDown.rawValue: key("Seta ↓"),
            PadButton.dpadLeft.rawValue: key("Seta ←"),
            PadButton.dpadRight.rawValue: key("Seta →"),
            PadButton.options.rawValue: key("Escape"),
            PadButton.create.rawValue: .none,
            PadButton.ps.rawValue: .missionControl,
            PadButton.touchpad.rawValue: .leftClick,
        ]
    }
}
