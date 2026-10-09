# Licença do Fist por funcionário — desenho

> Estado a 2026-10-09: **feito, provado no Redmi e publicado (Fist 0.3.79, Control 1.9.3).**
> **Modelo final** (supera as secções «Mudança de dados» e «Funções» abaixo, escritas antes de
> ler `punho_subscricoes`): a licença é uma linha por **empresa** em `licencas`
> (`empresa_id`, `machine_id = 'empresa:<uuid>'`); o funcionário é um lugar em `punho_membros`
> dentro do limite de `punho_subscricoes` (packs de 3 operadores; o gestor inclui o escritório);
> aparelhos em `fist_dispositivos` (máx. 2) e sessão única em `fist_sessoes`.
> Função nova **`licenca-fist`** (exige sessão); `registar-terminal` e `validar-licenca` ficam
> como estão para as apps já instaladas. Prova: `supabase/tests/licenca_fist_rest.sh` (12 de 12).
> Decisão do Cesar.
> Decisão dele: **um email, uma licença**. A licença é do funcionário e nunca do dispositivo.
> Contraparte no WashInvoice (presa ao PC): `washinvoice-pos/docs/seguranca/identidade_do_terminal.md`.

## O que está hoje, e porque não serve

- O Fist deriva o `machine_id` do `ANDROID_ID` (`lib/core/licenca/machine_id.dart`) e chama
  `registar-terminal` **no arranque, antes do login**, sem sessão (`licenca_service.dart`).
- A licença vive em `licencas`, uma linha por `(machine_id, app)`. É do **aparelho**: trocar
  de telemóvel, ou usar dois, cria terminais novos com 40 dias de trial cada.
- O email só aparece no acesso à empresa (`punho_membros.user_id`), não na licença.
- Em `licencas` **não existe** `user_id` nem `email` (verificado em produção a 2026-10-09).

## Regra

1. A licença do Fist pertence a **uma conta** (o utilizador de `auth.users`, identificado
   pelo email). A chave passa a ser `(user_id, app = 'punho')`.
2. **O dispositivo não conta.** Pode-se entrar do telemóvel que se quiser. O `machine_id`
   continua a ser enviado, mas só como informação (que aparelhos usaram esta conta).
3. Trial de **40 dias por email, uma só vez**. Apagar e recriar a conta com o mesmo email não
   repete o trial.
4. A identidade vem **sempre do token** (`auth.getUser(jwt)`), nunca do corpo do pedido —
   é a regra já seguida em `sincronizar-empresa-punho` e `gerir-licenca`.
5. **Sem rede: 28 horas.** O Fist guarda a hora da última validação do servidor com sucesso;
   passadas 28 horas sem nova validação, bloqueia («contacte a WashControl»). Cada resposta do
   servidor repõe o relógio. As 28 horas (e não 24) são decisão do Cesar, para lhe darem tempo
   de corrigir uma avaria. É mais apertado do que as 5 dias do WashInvoice. **A verificar:** o
   Fist ainda não guarda essa hora (não há cache de validação no código que li).

## Mudança de dados (proposta — precisa de ok antes de aplicar em produção)

Em `licencas`:

- acrescentar `user_id uuid` e `email text` (nulos, porque o WashInvoice continua por máquina);
- `machine_id` passa a poder ser nulo **para `app = 'punho'`**;
- índice único `(user_id, app)` onde `user_id` não é nulo — é o que garante uma licença por
  conta e impede o segundo trial.

RLS não muda: escreve o `service_role`, o admin só lê. O Control continua a mexer por Edge
Functions.

## Funções

| Função | Hoje | Passa a ser |
|---|---|---|
| `registar-terminal` (punho) | sem sessão, cria linha por máquina | **exige sessão**. Cria a licença trial da conta no 1.º login, se a conta ainda não tiver. O arranque antes do login deixa de registar nada. |
| `validar-licenca` (punho) | procura por `machine_id` | procura por `user_id` vindo do JWT. Durante a transição, sem JWT, cai para `machine_id` (apps antigas). |
| `gerir-licenca` | por `machine_id` | aceita o id da licença; a ficha do Control mostra o **email** em vez do aparelho. |

Cuidado de publicação: parte-se **sempre** da versão em produção (`supabase functions
download`), que tem os reforços de 10/08/2026 (rate-limit, autorização do NIF, `chave_mestre`
só para membros). Nada de repor versões antigas dos repositórios.

## No Control

- Os cartões e a ficha do Fist mostram o email (a cascata de nomes já existe; o email passa a
  ser o nome principal). «Terminal» deixa de ser o conceito do Fist.
- «Renovar» e «Suspender» atuam sobre a licença da conta.
- O limite de colaboradores que autorizas no Control (`limite-de-colaboradores`) continua a
  existir. **Em aberto:** cada funcionário paga a sua licença, ou a empresa paga e o limite
  é o número de lugares? A decisão «um email, uma licença» fixa a unidade técnica, não quem
  paga. Convém fixar isto antes de se mexer na faturação.

## Migração

Hoje há 4 licenças Fist, todas de teste e por aparelho (3 delas de emuladores ou do Redmi).
Em vez de as migrar, **deixam de contar**: cada conta recebe a sua no próximo login. As
linhas antigas apagam-se ou ficam como histórico. É grátis agora; com clientes a sério custaria
um trial duplicado por funcionário.

## Ordem de trabalho

1. Migração SQL (colunas, nulo em `machine_id`, índice único) — **precisa do teu ok**.
2. `registar-terminal` e `validar-licenca` (a partir da versão em produção) + testes com
   token real de um utilizador de ensaio (ver «ambiente de ensaio»).
3. Fist: tirar o registo do arranque, chamar após o login, guardar a data da última validação
   para a graça de 5 dias.
4. Control: mostrar o email, ajustar Renovar/Suspender.
5. Prova no Redmi, com toques reais, de **dois telemóveis na mesma conta** e de **troca de
   telemóvel** sem trial novo.

## Quem paga, e os dispositivos (decisões de 2026-10-09)

**Quem paga é sempre a empresa.** O funcionário nunca paga nem escolhe plano. A licença é
dele (uma por email), mas o plano e a validade são da empresa. O número de lugares é o limite
que autorizas no Control (`limite-de-colaboradores`): quem ultrapassa o limite cadastra-se mas
não acede, como já é hoje.

**Cada funcionário: no máximo 2 dispositivos, e nunca os dois ao mesmo tempo. Se um abre, o
outro fecha.**

Isto precisa de duas peças que ainda não existem:

1. **Lista de dispositivos da conta** — nova tabela (`fist_dispositivos`: `user_id`,
   `machine_id`, `nome`, `visto_em`). Um 3.º dispositivo é recusado com «Esta conta já usa 2
   aparelhos. Contacte a WashControl»; quem liberta um lugar és tu, no Control.
2. **Sessão única** — a conta tem uma só sessão ativa (`machine_id` + um número de sessão novo
   a cada abertura). Ao abrir, o aparelho **reclama** a sessão; o outro, ao validar ou ao
   voltar ao primeiro plano, vê que perdeu e fecha com «Sessão aberta noutro aparelho».
   Para o aviso chegar depressa usa-se a campainha em tempo real que o Fist já tem
   (`punho_campainha_tempo_real.sql`), com a validação periódica como rede de segurança.

**A brecha que tens de aceitar:** um aparelho **sem rede** não recebe o aviso. Com a graça de
5 dias, o aparelho A pode continuar a trabalhar offline enquanto o B está ativo, e as duas
sessões coexistem até A voltar à rede. O Fist já tem um log de operações e resolução de
conflitos, por isso não se perde dados, mas a regra «nunca os dois ao mesmo tempo» só é firme
com rede. Por isso a graça offline do Fist é curta: 28 horas.

## Perguntas ainda abertas

- **Trial por empresa ou por email?** Se for por email, uma empresa ganha 40 dias de graça
  para cada funcionário novo, indefinidamente. Recomendo: o trial é **da empresa**, começa no
  primeiro funcionário e acaba para todos no mesmo dia.
