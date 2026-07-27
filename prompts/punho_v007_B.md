# v0.0.7 · B — Sidebar + Rotas

Branch: `feat/v007-sidebar-empresa` — prompt A já commitado

## Tarefa 1 · Sidebar final

Ficheiro: `lib/features/shell/presentation/app_shell.dart`

1. Ordem dos destinos: `Painel · Máquinas · Reservas · Clientes · Colaboradores · Empresa · Tarefas`
2. `Empresa` abre `EmpresaPage`
3. Remover `Veículos` e `Finanças` como destinos directos (já vivem dentro de `Empresa`)
4. Badge no `Tarefas` mantém-se; larguras 88 dp como antes
5. Commit: `feat: sidebar refeita com 7 destinos`

Feito quando: sidebar mostra exactamente 7 destinos na ordem acima

---

## Tarefa 2 · Rotas e deep-links

1. Adicionar rota `/empresa` → `EmpresaPage`
2. `EmpresaPage` aceita parâmetro opcional `initialTab`
3. Rota `/veiculos` → `EmpresaPage(initialTab: EmpresaTab.veiculos)`
4. Rota `/financas` → `EmpresaPage(initialTab: EmpresaTab.financas)`
5. Commit: `feat: rotas Empresa com deep-link por aba`

Feito quando: navegar para `/veiculos` abre directamente na aba Veículos; `flutter analyze` limpo
