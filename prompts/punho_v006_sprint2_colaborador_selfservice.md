# Punho v0.0.6 — sprint 2 (self-service do colaborador)

> **Depende da sprint 1** (Frentes B — ContaScreen + convite WhatsApp —
> e C — campos fiscais no `Collaborator`) estar entregue. Não arrancar
> antes.
>
> Continua em `feat/v006-boas-vindas` ou nova branch a partir dela.
> 0.0.6 ongoing, só fecha quando o Cesar disser.

## Ideia central

Hoje o gestor introduz **todos** os dados dos colaboradores à mão:
nome, telefone, cargo, custo, NISS, estado civil, dependentes. É lento,
propenso a erros e cria ansiedade de RGPD (o gestor a manipular dados
fiscais alheios).

A partir desta sprint, o colaborador **preenche a sua própria ficha
fiscal**. O gestor só cria o convite (WhatsApp — já feito na 1-B) e
confirma no fim.

Fluxo:

1. **Gestor** entra em `ContaScreen`, toca `Convidar por WhatsApp`,
   escolhe email + perfil `Colaborador`, código gerado, mensagem
   enviada.
2. **Colaborador** recebe link no WhatsApp, instala Punho no telemóvel
   (ou abre no PC), regista-se com o código. Ao entrar, entra no
   *shell colaborador* já existente (portrait, 6 botões grandes).
3. **Primeira sessão do colaborador** — vê um card destacado no topo:
   *"A tua ficha está incompleta. Preenche em 2 minutos para a
   empresa poder processar salários."*
4. **Colaborador toca** → abre o `FichaFiscalColaboradorForm` (widget
   partilhado da sprint 1 Frente C). Preenche NISS, estado civil,
   dependentes, IBAN (novo — ver secção "Novos campos"), morada
   pessoal (novo).
5. **Ao guardar**, os dados vão para o `Collaborator` da empresa
   (via `updateFichaColaborador` no controller — nova RPC no lado
   Supabase). O gestor deixa de ver "NISS em falta" na `TarefasPage`.
6. **Gestor recebe push** (via a mesma infra do trigger de pedidos —
   task #196, extensão): "Ana Costa completou a ficha fiscal."

## Novos campos em `Collaborator` (adicionais aos da sprint 1)

- `String? iban` — IBAN pessoal do colaborador (para transferências
  bancárias). Validar com regex simples PT (`^PT50\d{21}$` sem espaços),
  aviso não bloqueante se falhar.
- `String? addressStreet`, `String? addressPostalCode`,
  `String? addressLocality` — morada pessoal (para folhas de salário e
  comunicações fiscais).
- `String? birthDate` — data de nascimento (ISO `YYYY-MM-DD`;
  opcional, útil para escalões etários no futuro).

Todos preenchidos pelo colaborador; opcionais na perspectiva do
gestor (não bloqueiam nada).

## Shell colaborador — novo card "Ficha por completar"

`lib/features/collaborator/presentation/collaborator_shell.dart` —
adicionar cartão superior condicional (só se `NISS == null` ou
`iban == null`):

```
⚠  A tua ficha está incompleta.
    Preenche NISS, IBAN e morada para a empresa poder processar
    salários e transferências.

    [ Completar ficha → ]
```

Card com bordo âmbar, `Icons.warning_amber_rounded`. Ao tocar, abre
`FichaFiscalColaboradorFormPage` (nova página portrait).

Quando a ficha ficar completa, o card desaparece.

## `FichaFiscalColaboradorFormPage`

Nova página que **reusa** o widget `FichaFiscalColaboradorForm` da
sprint 1. Diferenças em relação ao contexto do gestor:

- **Portrait obrigatório** — o shell colaborador é portrait, esta
  página também.
- **Todos os campos editáveis pelo próprio**, sem restrições de
  perfil (é a sua ficha).
- **Botão principal `Guardar e voltar`** (verde), secundário
  `Cancelar`.
- **Nota de privacidade** por baixo do NISS: *"Estes dados são
  visíveis para o gestor da tua empresa. Só ele — nenhum outro
  colaborador."*

## Lado Supabase

Nova RPC `punho_atualizar_ficha_colaborador(p_dados jsonb)`:

- `security definer`, ler `auth.uid()`.
- Encontrar o `punho_membros.id` associado a este `user_id`.
- Fazer `update` na tabela `punho_colaboradores` (que já existe ou é
  criada agora, se necessário) com os campos permitidos: nome, telefone,
  NISS, estado civil, dependentes, IBAN, morada, data nasc.
- **Não** permitir mudar `custo` nem `role` — só o gestor pode.
- Trigger `AFTER UPDATE` dispara push ao gestor quando os campos
  chave (NISS, IBAN) passam de `NULL` para valor. Mesmo padrão do
  #196.

Se o `punho_estado_operacional` (o payload JSON exclusivo do gestor)
tem os colaboradores como parte do JSON e não em tabela própria, esta
sprint precisa de **extrair** os colaboradores para tabela dedicada
com RLS por empresa. Isso é meia-sprint extra — o Code decide se
divide ou faz tudo aqui.

## Push ao gestor: "Ficha completada"

Extensão do padrão da task #196:

- Novo trigger `AFTER UPDATE ON punho_colaboradores` (ou o que ficar)
  que dispara `enviar-push` para os `admin_dispositivos` do gestor da
  empresa.
- **Só notificar** na transição `NISS == null → NISS presente`.
  Actualizações subsequentes não notificam (senão o gestor recebe 10
  pushes por dia).
- Payload: `title: "Ana Costa completou a ficha"`, `body: "NISS,
  IBAN e morada preenchidos. Confirma em Funcionários."`,
  `data: {app: punho, route: /gestao/funcionarios, colaborador_id}`.

## `CollaboratorsPage` do gestor — indicadores

- Colaborador com ficha completa: chip verde `FICHA COMPLETA`.
- Colaborador com ficha incompleta: chip âmbar `AGUARDA COLABORADOR`
  (em vez do actual `NISS em falta`, mais accionável — o gestor
  percebe que quem tem de agir é o outro).
- Gestor pode ainda editar manualmente pelo `_collaboratorDialog`
  (útil para pré-preencher casos em que o colaborador não tem
  telemóvel). Mas o caminho principal passa a ser self-service.

## Testes

- Widget test do card no shell colaborador:
  - Fixture com colaborador sem NISS → card visível.
  - Preencher ficha → card desaparece.
- Widget test do `FichaFiscalColaboradorFormPage`:
  - Todos os campos editáveis, `custo` e `role` **não** presentes.
  - Nota de privacidade visível.
- Widget test da `CollaboratorsPage` do gestor:
  - Chip verde `FICHA COMPLETA` vs âmbar `AGUARDA COLABORADOR`.
- Integration test (mocked Supabase):
  - Colaborador completa ficha → RPC chamada → trigger dispara →
    `enviar-push` recebe request com o gestor certo.

## Fora do âmbito

- Não implementar transferências bancárias reais — o IBAN é guardado
  para uso futuro (folha de salários), não é executado.
- Não gerar recibos de vencimento (roadmap de folha de pagamento é
  módulo próprio, provavelmente v0.1.x).
- Não implementar troca de dados entre colaboradores da mesma
  empresa — o colaborador só vê os seus.
- Não permitir ao colaborador mudar o próprio custo ou cargo — é
  informação do empregador.

## Gate

1. `flutter test` verde.
2. `flutter analyze` limpo.
3. Screenshots:
   - `shell_colaborador_card_ficha.png` (portrait, card âmbar visível)
   - `ficha_fiscal_form.png` (portrait, formulário aberto)
   - `funcionarios_lista_com_chips.png` (landscape, gestor vê os dois
     estados)
4. Verificação do push ficha completada: SQL de sonda (UPDATE do NISS
   de teste em `punho_colaboradores`) → `net._http_response` retorna
   200 → snapshot do trigger.
5. Doc `docs/design/punho_v006_sprint2.md` com racional, fluxos e
   screenshots.

## Entrega

Sem push, sem bump, sem APK. Report frente única no fim.
