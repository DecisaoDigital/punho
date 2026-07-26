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
