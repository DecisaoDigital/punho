# Formulários em ecrã completo — o que falta provar no telemóvel

Estado a 5 de Agosto de 2026. Todos os formulários da app deixaram de abrir em
diálogo. `flutter analyze` limpo, 816 testes verdes.

Aparelho de referência: Redmi Note 10 Pro (`M2101K6G`, série `94c906b9`),
Android 13, ligado por USB.

## As medidas, para não se voltar a discutir de cabeça

Medidas na app, em paisagem com o teclado aberto:

| | |
|---|---|
| Ecrã | 872,7 × 392,7 dp |
| Teclado | 200,4 dp |
| Sobra em altura | **192,4 dp** |
| Largura que chega ao corpo do formulário | 761,6 dp |
| Campo em tamanho normal | 56 dp |
| Campo apertado (`isDense`) | 48 dp |

Daqui sai tudo o resto: a altura é que escasseia, a largura sobra. Três colunas
de 240 dp põem seis campos à vista onde duas punham dois. Abaixo de 250 dp por
coluna os rótulos longos cortam.

## O que já foi provado no aparelho

- **Veículo** — quatro campos utilizáveis com o teclado aberto; *Seguinte*
  percorre Matrícula → Tipo → Nome → Prestação → Dia do débito e o campo focado
  nunca fica tapado; gravar `250,50` levou a frota de 485,00 para 735,50 €.
- **Máquina** — quatro campos à vista com o teclado aberto; a recusa "Indica o
  nome da máquina." aparece a 452 px, com o teclado a começar aos 529. Era um
  `SnackBar` e nascia por baixo dele.
- **Mudar palavra-passe** — dois campos ocultos, ambos à vista com o teclado
  aberto.
- **Sair sem guardar** — com texto escrito, a seta de retorno pergunta antes de
  deitar fora.

## O que falta correr

Em cada um: abrir em paisagem, tocar no primeiro campo, contar os campos que
ficam utilizáveis com o teclado aberto, e percorrer a cadeia toda com o
*Seguinte* a ver se algum campo focado fica debaixo do teclado.

- [ ] **Colaborador** — o mais fundo. Confirmar que o *Seguinte* atravessa a
      ficha fiscal (NIF, NISS, dependentes, IBAN, morada), que vive noutro
      ficheiro e dois níveis abaixo na árvore. Trocar de vínculo a meio do
      preenchimento e ver se a cadeia se recompõe.
- [ ] **Cliente** — oito campos. E abri-lo *a partir* do formulário de
      marcação, pelo "Novo cliente…" do dropdown: é ecrã por cima de ecrã, e o
      id do cliente novo tem de voltar para a marcação.
- [ ] **Lead** (app do gestor)
- [ ] **Lead** (app do colaborador) — e confirmar a recusa nova: sem nome ou
      sem telemóvel, dizer porquê em vez de o botão não fazer nada.
- [ ] **Marcação / reserva** — oito escolhas, com escolhedores de data por
      cima do formulário.
- [ ] **Confirmação de reserva** — a partir do calendário, ao tocar num slot.
- [ ] **Faturação do ano** — a partir da lista de Tarefas.
- [ ] **Valor do trabalho** — a partir de "A minha semana".
- [ ] **Enviar sugestão** — não foi corrido para não mandar uma sugestão a
      sério. Confirmar que a mensagem "Sugestão enviada. Obrigado!" aparece
      **uma vez** e não duas: a confirmação passou a ser dada por quem fica, e
      não pela rota que sai.
- [ ] **Convite do contabilista** — e que o link continua a aparecer a seguir.
- [ ] **Recuperar palavra-passe** — no ecrã de entrada, antes de haver sessão.

## Coisa que não se consegue provar no telemóvel

A app tranca paisagem no `AppShell` (`Orientacao.landscape`, um só lado), por
isso a coluna única de retrato não acontece num Redmi. Está provada por teste
em `test/core/layout/ecra_de_formulario_test.dart`: numa janela de 400 dp todos
os campos arrancam na mesma abcissa; numa de 1000 dp são três colunas; com
quatro campos não sobra coluna vazia.

## Achado por resolver, fora deste trabalho

**Eliminar um veículo diz que eliminou e não elimina.** No aparelho: eliminar
`XY99ZW` mostrou "XY99ZW eliminado.", com o *Anular* de 6 segundos, e o veículo
ficou na lista e no custo mensal da frota (735,50 €, sem descer). Sair do
separador e voltar não mudou nada.

Não vem daqui: o caminho de eliminação não foi tocado, e o teste
`test/features/workforce/vehicle_form_test.dart` — "eliminar arquiva com 6
segundos para anular" — passa. O que falha é só no aparelho, o que aponta para
a sincronização a repor o registo arquivado. Fica registado para se ver com
calma; mexer nisto era mexer em lógica de negócio.
