# Histórico de alterações

As alterações publicadas são agrupadas por versão e geradas automaticamente a partir dos commits convencionais. Consulte a página [Releases](https://github.com/andremaiqui/DualPad/releases) para baixar o app e ver as notas de cada versão.

## [1.3.0](https://github.com/andremaiqui/DualPad/compare/v1.2.0...v1.3.0) (2026-11-24)


### Novidades

* Alternância entre controles: escolha qual DualSense conectado será usado na janela principal ou no popover da barra de menus; o nome, a conexão e a bateria passam a refletir o controle selecionado. ([#14](https://github.com/andremaiqui/DualPad/issues/14))
* Seletor flutuante na janela principal: a lista abre sobre o cartão de conexão sem deslocar ou redimensionar a interface, e usa fundo opaco para manter os nomes legíveis.
* Estado do popover: a lista se fecha após a seleção e volta fechada quando o popover é dispensado e aberto novamente.
* Ícone estável: a imagem do app é mantida em cache para evitar recriação e cintilação durante as atualizações de estado do controle.

## [1.2.0](https://github.com/andremaiqui/DualPad/compare/v1.1.0...v1.2.0) (2026-11-24)

### Novidades

- Adicionado um popover na barra de menus com visual inspirado no Liquid Glass.
- Exibidos a ilustração do DualSense, o estado da conexão e a porcentagem da bateria.
- Incluídas ações rápidas para abrir a janela principal, ativar ou desativar o controle e encerrar o DualPad.

### Melhorias

- Refinado o popover com superfícies translúcidas, botões arredondados e apresentação adaptada aos modos claro e escuro.
- Aplicado o azul de destaque aos ícones das três ações para melhorar sua visibilidade.
- Fechado o popover ao clicar fora dele, evitando que permaneça sobre outros apps e janelas.
- Adaptadas as informações de bateria e conexão para os estados conectado e desconectado.

### Documentação

- Atualizada a captura do README para mostrar a versão atual do app em execução.

## [1.1.0](https://github.com/andremaiqui/DualPad/compare/v1.0.0...v1.1.0) (2026-11-23)


### Novidades

* Adicionado o modo **Testar controle**, com realce dos botões pressionados na imagem do DualSense.
* Exibidas as posições X/Y dos dois sticks e a intensidade dos gatilhos L2/R2 durante o teste.
* Bloqueadas as ações de mouse, teclado e rolagem do macOS enquanto o modo de teste estiver ativo.


### Correções

* Corrigido o piscar da imagem do controle durante as entradas com carregamento em cache.
* Ajustados tamanho, posição e contorno dos realces de L1/R1, L2/R2, D-pad, touchpad e botão PS.
* Diferenciados os realces de L1/R1 e L2/R2 e alinhados os símbolos na lista de mapeamentos.

## [1.0.0](https://github.com/andremaiqui/DualPad/releases/tag/v1.0.0) (2026-11-21)

### Novidades

- Use o DualSense como mouse, roda de rolagem e teclado no macOS.
- Configure a velocidade do cursor, a zona morta, a aceleração e a velocidade e direção da rolagem.
- Ative o touchpad para mover o cursor e escolha a ação do clique.
- Personalize as ações dos botões, gatilhos, D-pad e sticks; restaure os mapeamentos padrão quando quiser.
- Detecte automaticamente o controle conectado por Bluetooth ou USB e veja o nível da bateria.
- Use o modo Segundo plano para fechar a janela, ocultar o app da Dock e continuar usando os controles pelo ícone na barra de menus. Reabra a janela pelo menu ou encerre o app por ali.
- Acompanhe e solicite a permissão de Acessibilidade necessária para enviar ações de mouse e teclado.
- Aproveite uma interface SwiftUI que acompanha a aparência do sistema, com janela em tamanho fixo e ilustração oficial do controle.
- Alterne toda a interface entre Português (Brasil) e English (U.S.) em tempo real, incluindo mapeamentos, atalhos, estados e menu da barra de menus, sem reiniciar o app.
- Integre a área dos semáforos ao conteúdo da janela, removendo a linha divisória abaixo da barra superior.

### Privacidade e requisitos

- As entradas do controle são processadas localmente; o app não inclui telemetria nem envia dados pela rede.
- Requer macOS 26 ou posterior, um DualSense conectado e autorização de Acessibilidade para controlar o Mac.
- O download é fornecido como app para macOS dentro de `DualPad-macOS.zip`. O binário não é assinado nem notarizado com uma identidade Apple Developer.
