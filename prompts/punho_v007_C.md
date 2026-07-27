# v0.0.7 · C — Testes + Screenshots + Doc

Branch: `feat/v007-sidebar-empresa` — prompts A e B já commitados

## Tarefa 1 · Testes

1. Widget test `AppShell`: sidebar tem 7 destinos na ordem `Painel · Máquinas · Reservas · Clientes · Colaboradores · Empresa · Tarefas`
2. Widget test `EmpresaPage`: tap em cada aba mostra o widget correspondente
3. Widget test deep-link: `EmpresaPage(initialTab: EmpresaTab.veiculos)` abre na aba Veículos
4. Garantir que os testes de `VehiclesPage` e Finanças continuam a passar
5. Commit: `test: cobertura sidebar e EmpresaPage`

Feito quando: `flutter test` verde, contagem igual ou superior à anterior

---

## Tarefa 2 · Screenshots

Criar em `docs/design/screenshots/v007/` com `@Tags(['screenshot'])`:
- `sidebar_final.png`
- `empresa_aba_dados.png`, `empresa_aba_regime_fiscal.png`, `empresa_aba_custos_fixos.png`
- `empresa_aba_veiculos.png`, `empresa_aba_financas.png`, `empresa_aba_estado_placeholder.png`

Commit: `test: screenshots v007`

Feito quando: 7 PNG existem e `flutter test --exclude-tags screenshot` continua verde

---

## Tarefa 3 · Doc

Criar `docs/design/punho_v007_sprint1_sidebar.md` com:
- Tabela antes/depois da sidebar (destinos antigos vs novos)
- Referência aos screenshots de v007
- Notas técnicas: deep-links por aba, `VehiclesPage` e Finanças encaixados sem lógica nova
- Linha final: "Próximo: `CHECKLIST_v006_ATE_FIM.md` Prioridade 6b"

Commit: `docs: punho_v007_sprint1_sidebar.md`

Feito quando: ficheiro existe; reportar contagem final de testes e lista de ficheiros criados nesta sprint
