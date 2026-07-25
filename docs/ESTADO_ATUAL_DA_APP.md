# Estado atual do Punho

## Ja utilizavel no modo demonstracao local

- Onboarding guiado da empresa, forma juridica, equipa, frota e numero estimado de maquinas.
- Inventario de maquinas identificadas, estado, referencia e categoria.
- Clientes partilhados pela empresa e leads convertiveis em clientes.
- Reservas com cliente, maquina, periodo, valor previsto, estado e responsavel.
- Bloqueio de sobreposicao de maquinas em reservas confirmadas ou em aluguer.
- Registo de despesas, recebimentos, pagamentos pendentes e ligacao de recebimento a reserva.
- Custos estimados de colaboradores e frota, incluindo custo/hora e seguros anual/semestral mensalizados.
- Area de colaborador para criar leads, pedidos de reserva e recebimentos, sem acesso aos custos da empresa.
- Painel de gestao com indicadores e recomendacoes deterministicas.
- Dados de onboarding e operacao guardados no proprio dispositivo entre reinicios.

## Ja preparado para a aplicacao real

- Autenticacao Supabase, confirmacao de adesao a empresa e logout.
- Migration para onboarding atomico, RLS inicial e protecoes entre empresas.
- Modelos de outbox e idempotencia para a sincronizacao futura.
- Sincronizacao remota segura do estado completo do gestor, com revisao de conflitos.

## Ainda nao usar com dados reais

- Os repositorios de clientes, maquinas, reservas, financas, equipa e frota ainda nao escrevem em tabelas Supabase individuais; nesta fase o gestor sincroniza um estado operacional protegido.
- Nao ha sincronizacao granular de colaboradores, convidados reais, autorizacao pelo WashInvoice Control, camera/OCR real ou distribuicao Android validada.

## Proxima prioridade tecnica

Ligar os repositorios operacionais ao Supabase e guardar uma outbox local persistente. Sem isso, nao ha piloto real multi-dispositivo.
