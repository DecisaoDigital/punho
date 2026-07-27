# v0.0.7 · Passo 1 — Renomear rótulos e símbolos

Estás na branch `feat/v007-sidebar-empresa`.

## Ficheiros a tocar

- `lib/features/shell/presentation/app_shell.dart`
- `lib/core/navigation/app_destination.dart` (ou equivalente)
- `lib/features/dashboard/**` (cabeçalhos e títulos)
- `test/**` (strings de assertions)
- `docs/**` (texto livre)

## O que fazer

1. Usa o refactor tool do IDE para renomear os símbolos de código:
   - `Gestão` → `Painel`
   - `Frota` → `Veículos`
   - `Funcionários` → `Colaboradores`
2. Faz grep pelas strings literais nos mesmos três termos e corrige manualmente o que o refactor não apanhou.
3. Não renomear a Dart class `CollaboratorsPage` — só o rótulo visível na sidebar.
4. Corre `flutter analyze`. Zero erros.
5. Commit: `refactor: renomear Gestão→Painel, Frota→Veículos, Funcionários→Colaboradores`

## Feito quando

`flutter analyze` limpo e `grep -r "Gestão\|Frota\|Funcionários" lib/ test/ docs/` devolve zero resultados.
