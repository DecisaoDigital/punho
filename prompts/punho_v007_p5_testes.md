# v0.0.7 · Passo 5 — Testes

Estás na branch `feat/v007-sidebar-empresa`. Passos 1–4 já commitados.

## O que escrever

1. **Widget test `AppShell`**: sidebar tem 7 destinos, na ordem `Painel · Máquinas · Reservas · Clientes · Colaboradores · Empresa · Tarefas`, com os rótulos correctos.
2. **Widget test `EmpresaPage`**: 6 abas presentes; tap em cada uma mostra o widget correspondente.
3. **Widget test deep-link**: `EmpresaPage(initialTab: EmpresaTab.veiculos)` abre directamente na aba Veículos.
4. Garantir que os testes das páginas migradas (`VehiclesPage`, ecrã de Finanças) continuam a passar — só o ponto de entrada mudou, não a lógica.

## Commit

`test: cobertura sidebar e EmpresaPage`

## Feito quando

`flutter test` verde, contagem de testes igual ou superior à anterior.
