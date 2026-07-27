# v0.0.7 · Passo 3 — Sidebar final

Estás na branch `feat/v007-sidebar-empresa`. Passos 1 e 2 já commitados.

## Ficheiro a tocar

`lib/features/shell/presentation/app_shell.dart`

## O que fazer

1. Ordem final dos destinos na sidebar:
   `Painel · Máquinas · Reservas · Clientes · Colaboradores · Empresa · Tarefas`
2. Adicionar `Empresa` como destino que abre `EmpresaPage`.
3. Remover `Veículos` e `Finanças` como destinos directos da sidebar (já vivem dentro de `Empresa`).
4. Badge no `Tarefas` mantém-se como está.
5. Larguras e ícones seguem o padrão 88 dp existente.

## Commit

`feat: sidebar refeita com 7 destinos e Empresa integrado`

## Feito quando

App corre, sidebar mostra exactamente 7 destinos na ordem acima, sem `Veículos` nem `Finanças` directos.
