# Limitações conhecidas

Actualizado na sprint de estabilização v0.0.3.

## Continuam a aplicar-se

- Dados operacionais só no dispositivo; sem sincronização granular
  multi-dispositivo. O gestor sincroniza um estado operacional completo, não
  tabelas individuais.
- Outbox offline, migração de dados, upload privado e integração de subscrição
  não estão implementados.
- OCR/QR são abstrações; não existe leitura local real integrada.
- A câmara Android ainda não está ligada.
- Os dados de piloto devem ser fictícios e não sensíveis.

## Já não se aplicam

- ~~Autenticação e convites não estão ligados a Supabase.~~ Desde a v0.0.2:
  registo, pedido de acesso com aprovação manual, convites de gestor por código
  e gate de sessão estão ligados ao Supabase. Ver
  `docs/design/punho_v002_contas_organizacao.md`.
- ~~Dados demo em memória.~~ Onboarding e operação persistem no dispositivo
  entre reinícios.

## Novas, descobertas na v0.0.3

- **A UI de autorização no Decisão Digital Control ainda não existe.** O schema
  suporta aprovar/recusar/revogar com service role, mas do lado do Control está
  por fazer: hoje aprova-se à mão em SQL.
- **Não é possível editar nem arquivar um cliente** depois de criado. Ver
  `BACKLOG_v0.0.4.md`.
- **A identidade do colaborador não cruza os dois mundos.** O que fica gravado
  em `collaboratorResponsibleId` é o id da conta Supabase, que não corresponde
  ao id do `Collaborator` no repositório local. "A minha atividade" de um
  colaborador real não bate com a ficha de colaborador da empresa.
- **Limpar a diária de uma máquina não a limpa** (`copyWith` com `??`).
- **Vários enums aparecem em inglês** na interface (categoria de despesa, método
  de pagamento, estado da lead e da marcação).
- **O smoke de RLS ainda não foi corrido** contra uma base real —
  `supabase/tests/rls_smoke_isolamento_empresas.sql` está escrito e por executar.
- **Os edge cases de rede, sessão expirada, duplo toque e rotação não foram
  verificados.** Lista completa em `AUDITORIA_BUGS_v0.0.3.md`, secção "Por
  verificar à mão".

## Dívida deixada em aberto pelo hardening de 10/08/2026

- **Qualquer pessoa forja uma aceitação de termos com o `machine_id` de outro.**
  A migration `20260810120000_fechar_tabelas_partilhadas_do_pos.sql` fechou as
  sete tabelas partilhadas com o WashInvoice, mas manteve de pé o `INSERT`
  anónimo em `pings` e `aceites_termos`. Manteve-o por uma razão concreta: o POS
  não tem conta nenhuma em `auth.users` — zero, verificado — e este é o único
  caminho que tem para escrever. Tirá-lo cegava seis terminais e calava a prova
  de aceitação de termos.

  O preço é que a porta continua aberta a quem tiver a chave anon, que é
  pública por definição. `aceites_termos` é prova contratual: guarda machine_id,
  NIF, IP e cidade de quem aceitou. Com o `INSERT` aberto, um terceiro insere
  uma linha com o `machine_id` de um cliente e a prova deixa de provar. Em
  `pings` o estrago é menor — telemetria envenenada, terminais que não existem.

  **Aceitável hoje** porque não há um único cliente real no POS: os dados são
  todos de teste.

  **Solução:** mover as duas escritas para uma Edge Function com service_role,
  exactamente como a `receber-lead` já faz — a função recebe o pedido, valida o
  `machine_id` contra `licencas`, e só depois escreve. Aí o `INSERT` anónimo
  desaparece das duas tabelas e o revoke a `anon` fica completo.

  **Quando:** antes do primeiro cliente real do POS. Não antes, e não depois.
  Implicará mexer no código do POS, que não está nesta máquina — contar com isso
  no planeamento.

- **A `validar-licenca` continua a responder a quem tiver só a chave anon.** Tem
  de continuar: o POS não tem conta nenhuma e o Punho valida no arranque, antes
  do login. Quem souber um `machine_id` obtém estado, plano, validade, nome e
  NIF dessa instalação. O que saiu da resposta foi a `chave_mestre`, que era o
  único segredo lá dentro; o resto é o que o terminal precisa de saber sobre si
  próprio. Atenua o risco os `machine_id` serem SHA-256 — não se enumeram —, mas
  quem tiver acesso ao aparelho tem o dele. Fecha-se junto com a dívida dos
  `pings`/`aceites_termos`, na mesma Edge Function com service_role.

- **O rate-limit da `registar-terminal` é por IP, e um IP não é uma pessoa.**
  Dez terminais novos por hora por IP trava um varrimento de uma máquina só; não
  trava quem tenha IPs rotativos, e conta como um só toda uma rede atrás do
  mesmo NAT. É o que se consegue sem identidade — e identidade é precisamente o
  que o POS não tem. Se um dia uma loja legítima levar `429` a instalar, o
  número está numa constante no topo da função.

- **Um terminal do POS já não consegue corrigir sozinho um NIF que nasceu
  `000000000`.** Escrever o NIF de uma licença que já existe passou a exigir
  sessão de utilizador, e o POS não tem contas. Hoje isto não afecta nada — as
  três licenças do POS têm NIF real, posto na criação —, mas se algum terminal
  usar esse caminho vai receber `401`. Foi decisão deliberada: falhar alto agora,
  com dados de teste, em vez de deixar a porta aberta.

- **A `chave_mestre` sai para qualquer membro activo da empresa, gestor ou
  colaborador.** É deliberado: é a chave que liga o aparelho à empresa, e o
  aparelho de um colaborador também precisa de se ligar. Se um dia o modelo
  passar a exigir gestor, muda-se o predicado — está num sítio só,
  `validar-licenca`, no bloco da `chave_mestre`.
