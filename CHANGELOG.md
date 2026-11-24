# Histórico de alterações

As alterações publicadas são agrupadas por versão e geradas automaticamente a partir dos commits convencionais. Consulte a página [Releases](https://github.com/andremaiqui/DualPad/releases) para baixar o app e ver as notas de cada versão.

## [1.2.0](https://github.com/andremaiqui/DualPad/compare/v1.1.0...v1.2.0) (2026-11-24)


### Novidades

* add glass controller menu bar popover ([8293d11](https://github.com/andremaiqui/DualPad/commit/8293d11aa61c2b10f0279f1bfdd832656923d0b1))
* add Liquid Glass controller menu bar popover ([fb4cff4](https://github.com/andremaiqui/DualPad/commit/fb4cff4d22eee06887bbca8272946ebae3fd334c))


### Correções

* dismiss menu bar popover on outside clicks ([f4da608](https://github.com/andremaiqui/DualPad/commit/f4da608ef3725c9a02cb0b3523f3ed80542baaf8))
* dismiss menu bar popover on outside clicks ([d5a5f62](https://github.com/andremaiqui/DualPad/commit/d5a5f620a8166c7f477139d632fe8d407cf03da7))
* improve menu bar action icon visibility ([665e744](https://github.com/andremaiqui/DualPad/commit/665e744e12ebafea6127b12c7e910b7d42b53bd2))
* improve menu bar action icon visibility ([3dfe02e](https://github.com/andremaiqui/DualPad/commit/3dfe02e5c052ffaaa04fde1c0ca2c741a3f53769))


### Documentação

* refresh README screenshot ([f4bcbab](https://github.com/andremaiqui/DualPad/commit/f4bcbab9a4699962f023a5fb3cf7d7f9b38a9d05))
* refresh README screenshot ([e5429f4](https://github.com/andremaiqui/DualPad/commit/e5429f44d6eec5157141d869c8aed1ad67733240))
* update README app screenshot ([83611ac](https://github.com/andremaiqui/DualPad/commit/83611ac27a5fbfb27565f4262aaf345d0c579b1b))
* update README app screenshot ([c9d26b3](https://github.com/andremaiqui/DualPad/commit/c9d26b35dc9060aed3cc1daf03afb489b54556fa))

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
