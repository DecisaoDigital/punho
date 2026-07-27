# v0.0.7 · Passo 4 — Rotas e deep-links

Estás na branch `feat/v007-sidebar-empresa`. Passos 1–3 já commitados.

## O que fazer

1. Adicionar rota `/empresa` que abre `EmpresaPage`.
2. As rotas antigas `/veiculos` e `/financas` continuam a existir mas passam a navegar para `EmpresaPage` com a aba pré-seleccionada:
   - `/veiculos` → `EmpresaPage(initialTab: EmpresaTab.veiculos)`
   - `/financas` → `EmpresaPage(initialTab: EmpresaTab.financas)`
3. `EmpresaPage` aceita parâmetro opcional `initialTab` (enum ou índice inteiro).

## Commit

`feat: rotas Empresa com deep-link por aba`

## Feito quando

Navegar para `/veiculos` abre `EmpresaPage` directamente na aba Veículos. `flutter analyze` limpo.
