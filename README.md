# DualPad

Use um controle DualSense como mouse, scroll e teclado no macOS. O DualPad usa SwiftUI para a interface, GameController para receber os controles e eventos de acessibilidade do macOS para operar mouse e teclado.

## Requisitos

- macOS 26 ou posterior.
- Xcode 26 ou posterior.
- Controle DualSense conectado por Bluetooth ou USB.
- Acesso de Acessibilidade para enviar eventos de mouse e teclado.

## Compilar

1. Abra `DualPad.xcodeproj` no Xcode.
2. Selecione o esquema **DualPad** e o destino **My Mac**.
3. Compile e execute com **Product → Run**.

O projeto não usa App Sandbox porque o sandbox impede o envio dos eventos necessários para controlar o Mac. A assinatura estável de desenvolvimento ajuda o macOS a preservar a autorização de Acessibilidade entre compilações feitas neste projeto.

## Primeira execução

1. Conecte o DualSense.
2. Abra o DualPad e escolha **Pedir** na seção **Acessibilidade**.
3. Em **Ajustes do Sistema → Privacidade e Segurança → Acessibilidade**, permita o DualPad.
4. Volte ao app. A conexão do controle é detectada automaticamente.

O macOS exige que a pessoa autorize o acesso de Acessibilidade. O DualPad pode abrir o painel e solicitar a autorização, mas não pode concedê-la por você.

## Controles padrão

| Entrada | Ação |
|---|---|
| Stick esquerdo | Mover cursor |
| Stick direito | Rolar |
| Touchpad | Mover cursor, se ativado |
| ✕, R2 e clique no touchpad | Clique esquerdo |
| □ e L2 | Clique direito |
| R3 | Clique do meio |
| ○ e Options | Escape |
| △ | Return |
| L1 e R1 | Voltar e avançar |
| D-pad | Setas do teclado |
| Botão PS | Mission Control |

As ações podem ser alteradas nos menus de cada botão.

## Barra de menus

Ative **Segundo plano** para manter o DualPad disponível pelo ícone na barra de menus. Fechar a janela não encerra o app; escolha **Sair do DualPad** no menu para encerrar.

## Releases e versões

As versões seguem [Versionamento Semântico](https://semver.org/lang/pt-BR/). Os commits usam o padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/):

- `feat: ...` para melhorias que adicionam comportamento.
- `fix: ...` para correções.
- `docs: ...`, `refactor: ...` e `chore: ...` para documentação e manutenção.

O GitHub Actions compila o projeto em cada pull request e atualização na branch principal. O Release Please mantém o changelog, abre uma pull request de versão e, quando ela é integrada, cria um release com título `DualPad vX.Y.Z` e notas agrupadas por tipo de melhoria. Cada release inclui um arquivo ZIP do app para macOS.

Os binários publicados não são assinados nem notarizados com uma identidade de desenvolvedor. Para abrir um download público pela primeira vez, talvez seja necessário usar **Abrir** no menu de contexto do Finder. A assinatura de distribuição e a notarização podem ser adicionadas quando houver um certificado Apple Developer disponível.

## Estrutura

- `ContentView.swift` — interface SwiftUI e cenas do app.
- `ControllerManager.swift` — descoberta do controle, leitura de entradas e persistência das preferências.
- `EventPoster.swift` — eventos de mouse, scroll e teclado do macOS.
- `Models.swift` — controles, atalhos e preferências.
- `DualSenseController.png` — ilustração do controle.
- `DualPad.icns` — ícone do app.

## Privacidade

O DualPad processa localmente as entradas do controle. Não inclui telemetria nem envia dados pela rede. O acesso de Acessibilidade é usado para postar eventos de mouse e teclado.
