import Foundation
import CoreGraphics

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
        case .l3: return "L3 (clique do stick esquerdo)"
        case .r3: return "R3 (clique do stick direito)"
        case .dpadUp: return "D-pad ↑"
        case .dpadDown: return "D-pad ↓"
        case .dpadLeft: return "D-pad ←"
        case .dpadRight: return "D-pad →"
        case .options: return "Options"
        case .create: return "Create"
        case .ps: return "Botão PS"
        case .touchpad: return "Clique do touchpad"
        }
    }
}

// MARK: - Atalhos de teclado

struct Shortcut: Codable, Hashable {
    var label: String
    var keyCode: UInt16
    var flagsRaw: UInt64

    var flags: CGEventFlags { CGEventFlags(rawValue: flagsRaw) }

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
        Shortcut(label: "⌃↑ (Mission Control)", keyCode: 126, flagsRaw: ctrl),
    ]
}

// MARK: - Ações

enum PadAction: Codable, Hashable {
    case none
    case leftClick
    case rightClick
    case middleClick
    case key(Shortcut)

    var title: String {
        switch self {
        case .none: return "Nada"
        case .leftClick: return "Clique esquerdo"
        case .rightClick: return "Clique direito"
        case .middleClick: return "Clique do meio"
        case .key(let s): return "Tecla: \(s.label)"
        }
    }

    static let all: [PadAction] =
        [.none, .leftClick, .rightClick, .middleClick] + Shortcut.presets.map { .key($0) }
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
            PadButton.ps.rawValue: key("⌃↑ (Mission Control)"),
            PadButton.touchpad.rawValue: .leftClick,
        ]
    }
}
