# Licença do Fist por funcionário — desenho

> Estado: **desenho, por implementar**. 2026-10-09, com o Cesar.
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
5. Sem rede: uns dias de graça com a última validação guardada, depois bloqueia. Mesma regra
   do WashInvoice (5 dias, repostos por uma validação do servidor com sucesso). **A verificar**
   se o Fist já guarda a data da última validação; não li o código por inteiro.

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

## Perguntas ainda abertas

- Um funcionário pode usar dois telemóveis ao mesmo tempo? Pela regra «nunca presa ao
  dispositivo» a resposta é sim; fica assumido até dizeres o contrário.
- Quem paga: o funcionário ou a empresa (ver «No Control»).
