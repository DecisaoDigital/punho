# Punho v0.0.6 — sprint 3 (WhatsApp manual da reserva + retorno de clientes)

> **Depende da sprint 1 e 2** da 0.0.6 estarem entregues (ou pelo menos
> a Frente B da sprint 1 — que introduz o partilhar WhatsApp — em
> merge). Continua em `feat/v006-boas-vindas`. 0.0.6 ongoing, só fecha
> quando o Cesar disser.

Encosta a duas peças do roadmap vivo:

- §6 (Clientes, retenção e contacto): identificar quem não volta,
  botão de contacto, motivo do não-retorno.
- §8.1 (Primeira fase de WhatsApp): mensagens editáveis preparadas a
  partir da reserva, o gestor confirma manualmente.

Três frentes independentes. Commit por frente.

- **Frente A** — serviço partilhado `WhatsAppMessenger` (extrai a
  lógica actual espalhada, dá base para tudo o resto).
- **Frente B** — mensagens preparadas na ficha da reserva
  (confirmação, lembretes, cobrança).
- **Frente C** — painel "Clientes que não voltam" com contacto e
  motivo do não-retorno.

---

## Frente A — Serviço `WhatsAppMessenger`

Hoje o partilhar WhatsApp existe em dois sítios pelo menos
(`convites_screen.dart` da 0.0.5, `ContaScreen` da sprint 1 da 0.0.6)
e cada um constrói o URL à mão. Extrair um serviço partilhado antes de
esta sprint multiplicar mais os pontos.

### Novo ficheiro

`lib/core/comms/whatsapp_messenger.dart`:

```dart
class WhatsAppMessenger {
  const WhatsAppMessenger({UrlLauncher launcher = const _RealLauncher()});
  final UrlLauncher _launcher;

  /// Abre o WhatsApp com o [texto] pré-preenchido.
  /// Se [numero] for null ou vazio, abre wa.me/?text= (o gestor escolhe
  /// contacto no app). Números portugueses sem +351 são normalizados.
  /// Devolve `true` se lançou o URL; `false` se o WhatsApp não estiver
  /// disponível ou o URL não puder ser aberto (a UI trata do fallback).
  Future<bool> partilhar({String? numero, required String texto});

  /// Normalizador exposto para testes.
  static String? normalizarNumeroPT(String? n);
}
```

Regras:

1. `normalizarNumeroPT`: se `n` começa por `+`, mantém; se tem 9
   dígitos e começa por `9`, prefixa `+351`; senão devolve `null` (o
   telefone não é reconhecível — o serviço abre `wa.me` sem número).
2. Mensagem passa por `Uri.encodeComponent`.
3. URL: `https://wa.me/{numero_sem_+}?text={mensagem}` ou
   `https://wa.me/?text={mensagem}`.
4. Se `launchUrl` devolve `false` ou lança → registar no clipboard o
   texto todo (com prefixo do número se existir) e devolver `false`.

### Alterações a call sites existentes

- `convites_screen.dart::_partilharWhatsApp()`: passar a chamar
  `WhatsAppMessenger.partilhar`. Se falhar, snackbar
  `'Não consegui abrir o WhatsApp. O convite foi copiado para a área
  de transferência.'`.
- `ContaScreen` (sprint 1): mesma coisa.
- Deprecar o método `_partilharWhatsApp` local em `convites_screen.dart`.

### Testes

- Unit test `normalizarNumeroPT`:
  - `'+351912345678'` → `'+351912345678'`.
  - `'912345678'` → `'+351912345678'`.
  - `'12345'` → `null`.
  - `null`/`''` → `null`.
- Unit test `WhatsAppMessenger.partilhar` com launcher fake:
  - Com número válido: URL `https://wa.me/351912345678?text=…`.
  - Sem número: URL `https://wa.me/?text=…`.
  - Texto especial (`&`, `?`, `\n`, `€`) fica correctamente encoded.
  - Launcher devolve false → devolve false + escreve no clipboard.

---

## Frente B — Mensagens preparadas na ficha da reserva

O gestor abre uma reserva e tem à distância de dois toques uma
mensagem WhatsApp com os dados certos. Sem automação, sem envio pela
Punho — o botão é sempre `Abrir no WhatsApp`, o gestor decide se
envia.

### Onde vive

Na `BookingsPage` (agenda) — cada reserva já tem detalhes acessíveis
por tap no bloco do slot. Adicionar aí um novo botão **`Contactar
cliente`** (`FilledButton.tonal.icon` com `Icons.chat_outlined`).

Se o ecrã de detalhe da reserva não existir como página própria (só
como bottom sheet), tanto faz — o botão vive onde os detalhes
aparecem. Passa a `Contactar cliente ▾` (menu suspenso) com cinco
opções.

### Cinco tipos de mensagem

Cada uma com **template editável** por empresa (guardado em
`OnboardingData` ou em novo `AppSettings` — Code decide, desde que
persista com a mesma serialização usada para o resto). Templates
default (podem ser refinados depois):

| Tipo | Quando faz sentido | Template default |
|---|---|---|
| `confirmacao` | Assim que a reserva é criada | *"Olá {cliente}, a sua reserva na {empresa} está confirmada: {máquina} de {inicio} a {fim}. Qualquer coisa, é só responder por aqui."* |
| `pedidoConfirmacao` | 48 h antes do início | *"Olá {cliente}, aqui da {empresa}. A sua reserva de {máquina} começa em {inicio} — pode confirmar que continua tudo certo?"* |
| `lembreteLevantamento` | Dia D, manhã | *"Bom dia {cliente}. A sua {máquina} está pronta para levantar hoje a partir de {hora}. Até já."* |
| `lembreteDevolucao` | Dia F, manhã | *"Bom dia {cliente}, um lembrete de que a devolução da {máquina} é hoje até {hora}. Obrigado."* |
| `cobranca` | Reserva concluída, valor por receber | *"Olá {cliente}, agradeço a confiança na {empresa}. Falta liquidar o valor de {valor} referente a {máquina} ({inicio}–{fim}). Pode transferir para IBAN {iban_empresa} ou pagar quando passar cá."* |

Substituições disponíveis nos templates: `{cliente}`, `{empresa}`,
`{máquina}`, `{inicio}`, `{fim}`, `{hora}`, `{valor}`, `{iban_empresa}`.
Se um placeholder não tem valor no contexto (ex.: valor null), remove
a frase toda que o contém em vez de deixar `{valor}` no meio da
mensagem.

### Fluxo

1. Tocar no `Contactar cliente ▾` abre popup com as 5 opções.
2. Seleccionar uma → abre `AlertDialog` com **preview editável** da
   mensagem (o gestor pode ajustar). Título: `'Confirmar
   reserva — WhatsApp'` etc.
3. Botões: `Cancelar` e `Abrir no WhatsApp`.
4. Ao confirmar → `WhatsAppMessenger.partilhar` com
   `numero = cliente.telefone` e `texto = mensagem_preview`.
5. **Registar intenção** (novo `Communication`, ver secção seguinte).

### Registo interno da intenção

Novo modelo `Communication` (nome PT: `Comunicacao` se preferires) em
`lib/domain/models/communication.dart`:

```dart
enum CommunicationChannel { whatsapp, other }
enum CommunicationKind {
  confirmacao,
  pedidoConfirmacao,
  lembreteLevantamento,
  lembreteDevolucao,
  cobranca,
  reengajamento, // usada pela Frente C
  outra,
}

class Communication {
  final String id;
  final DateTime at;
  final CommunicationChannel channel;
  final CommunicationKind kind;
  final String? clientId;
  final String? bookingId;
  final String? collaboratorId; // quem gerou
  final String messagePreview; // primeiros ~120 chars
}
```

Persistência: nova secção no `PersistentOperationRepository` (mesma
lógica de outros modelos). RLS/Supabase: fora de âmbito nesta sprint
(fica local). Mostrado no futuro na ficha do cliente e da reserva
("Contactado em X para Y"), mas nesta sprint basta guardar.

**Regra importante:** só registamos que **abrimos o WhatsApp com uma
mensagem**. Não sabemos se o gestor enviou, nem a resposta. Registar
"intenção", não "envio".

### Templates editáveis por empresa

Novo destino? Não. Cabe em `CompanySettingsPage` /
`EmpresaDadosForm`: nova secção colapsável **"Mensagens do WhatsApp"**
com os 5 templates (cada um em `TextField.multiline`, com o glossário
de `{placeholders}` disponível à direita).

### Testes

- Unit test da substituição de placeholders:
  - Todos os placeholders resolvidos → mensagem completa.
  - Placeholder ausente → frase que o contém cai.
- Widget test do menu na `BookingsPage`:
  - Tocar em `Contactar cliente ▾` → 5 opções visíveis.
  - Seleccionar `cobrança` → diálogo abre com preview editável +
    valor da reserva substituído.
  - Confirmar → `WhatsAppMessenger.partilhar` chamado com
    `numero = cliente.telefone`.
- Widget test da secção de templates em `EmpresaDadosForm`:
  - Editar template `confirmacao` e guardar → persiste no repositório.

---

## Frente C — Painel "Clientes que não voltam"

Novo painel accionável, alimentado por regra determinística. Vive em
duas entradas:

1. **KPI no Slide 2 do Dashboard** (Pipeline & compromissos)
   — substitui uma das células (a "Cauções", que hoje é
   maioritariamente "por apurar") por
   **"Clientes a reengajar"**: número + sub-linha
   `X sem voltar há >18 dias · Y há >40 dias` + CTA "Abrir painel →".
2. **Nova página `RetornoClientesPage`** acessível pela CTA. Não
   entra na sidebar principal — é destino secundário.

### KPI puro

`lib/core/operations/kpis.dart` (ou ficheiro próprio
`retorno_clientes.dart`):

```dart
class ClienteEmRisco {
  final Client cliente;
  final Booking ultimaReserva;
  final int diasSemVoltar;
  final int totalRecebidoCents;
  final MotivoNaoRetorno? motivoRegistado;
}

class RetornoClientesResumo {
  final int totalMais18Dias;
  final int totalMais40Dias;
  final List<ClienteEmRisco> clientesMais40Dias;
  final List<ClienteEmRisco> clientesMais18Dias;
}

RetornoClientesResumo clientesQueNaoVoltam({
  required DateTime now,
  required List<Client> clientes,
  required List<Booking> reservas,
  required List<Recebimento> recebimentos,
  int limiar1Dias = 18,
  int limiar2Dias = 40,
});
```

Regras:

- Só conta clientes com pelo menos uma reserva **concluída**
  (`status == completed`). Reservas activas ou canceladas não contam
  para "não voltou".
- `diasSemVoltar` = dias desde a última `completed`.
- `totalRecebidoCents` = soma dos recebimentos ligados a este cliente
  (por `clientId`).
- Limiares configuráveis; defaults 18 e 40.
- Cliente com motivo `outro` ou `semNecessidade` no último contacto
  **de reengajamento** dos últimos 60 dias sai do painel — o gestor já
  actuou e o cliente disse "não neste momento", não vale a pena
  repetir.

### Motivos de não-retorno

Enum novo `MotivoNaoRetorno`:

- `semNecessidade`
- `preco`
- `concorrencia`
- `indisponibilidade`
- `insatisfacao`
- `faltaResposta`
- `outro`

Guardado como campo `motivoUltimoContacto` no `Client`, opcional
(`Campo<MotivoNaoRetorno>?` pelo padrão que a app já usa).

### `RetornoClientesPage` — layout

Landscape, duas secções:

- **Topo**: dois chips grandes
  `>18 dias: N` (âmbar) · `>40 dias: M` (vermelho). Chip activo filtra a lista.
- **Lista**: `ListView` por `ClienteEmRisco`. Cada linha:
  - Nome do cliente + telefone
  - Última reserva (data + máquina)
  - Dias sem voltar em destaque
  - Total já recebido em €
  - Origem da primeira lead (quando conhecida — se não, `—`)
  - Botão **`Reengajar por WhatsApp`** → abre diálogo com preview
    editável de um template default *"Olá {cliente}, aqui da {empresa}.
    Faz já {dias} dias que não passa por cá — está tudo bem? Se
    precisar de uma máquina, é só dizer."* + `WhatsAppMessenger`.
  - Botão secundário **`Registar motivo`** → popup com o enum
    `MotivoNaoRetorno`; ao guardar, grava em `Client.motivoUltimoContacto`
    e regista `Communication.kind == outra` com preview
    `"Motivo registado: {motivo}"`.

### Tarefas

- Adicionar fonte à `TarefasPage`: se `RetornoClientesResumo.totalMais40Dias
  > 0`, aparece linha **⚠️ Urgente** *"{n} clientes há mais de 40 dias
  sem voltar"* com CTA "Abrir painel →".

### Testes

- Unit test `clientesQueNaoVoltam`:
  - Fixture com clientes activos, arquivados, com/sem reservas
    concluídas, várias datas. Assert nos totais e nas listas.
  - Cliente contactado nos últimos 60 d com motivo `semNecessidade`
    → sai do painel.
- Widget test da `RetornoClientesPage`:
  - Chips filtram a lista.
  - `Reengajar por WhatsApp` abre diálogo → confirmar chama
    `WhatsAppMessenger.partilhar` com telefone certo.
  - `Registar motivo` grava no `Client` e regista `Communication`.
- Widget test do Slide 2 do Dashboard:
  - Novo KPI substitui "Cauções", sub-linha com contagens.
- Widget test da `TarefasPage`:
  - Fixture com 3 clientes >40d → linha urgente aparece.

---

## Fora do âmbito

- Automação de envio (envio programado, integração WhatsApp Business
  API): fica para o Punho IA Pro (§8.2 do roadmap).
- Guardar respostas do cliente: WhatsApp manual não expõe respostas
  ao Punho, não inventamos.
- Reclamações estruturadas: sprint dedicada (§7 do roadmap).
- Funil comercial completo (lead → cliente → receita atribuída):
  outra sprint (§5 do roadmap).
- Sincronizar `Communication` via Supabase: fica local nesta sprint;
  RLS + tabela remota vem depois com a sincronização granular por
  entidade (P1 do roadmap).

## Gate

1. `flutter test` verde. Reportar contagem antes/depois.
2. `flutter analyze` limpo.
3. Screenshots novos:
   - `whatsapp_menu_reserva.png` (bottom sheet com 5 opções)
   - `whatsapp_preview_cobranca.png` (diálogo com preview editável)
   - `retorno_clientes_painel.png` (landscape, lista com botões)
   - `dashboard_slide2_com_reengajar.png`
   - `empresa_form_templates_whatsapp.png`
4. Doc `docs/design/punho_v006_sprint3.md` com racional das três
   frentes, fluxos e screenshots.
5. Actualizar §3.5 do `DECISOES_E_ROADMAP_VIVO.md` com o que ficou
   feito e marcar §6 e §8.1 como "implementado localmente".

## Entrega

Continua em `feat/v006-boas-vindas`. Três grupos de commits, um por
Frente. Sem push, sem bump, sem APK. Report frente-a-frente no fim.
