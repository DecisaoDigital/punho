# v0.0.7 · A — Renomear + EmpresaPage

Branch: `feat/v007-sidebar-empresa`

## Tarefa 1 · Renomear rótulos

Ficheiros: `app_shell.dart`, `app_destination.dart`, `lib/features/dashboard/**`, `test/**`, `docs/**`

1. Refactor tool do IDE: `Gestão→Painel`, `Frota→Veículos`, `Funcionários→Colaboradores`
2. Grep manual pelos mesmos termos e corrige o que escapou
3. Não renomear a Dart class `CollaboratorsPage` — só o rótulo visível
4. `flutter analyze` limpo
5. Commit: `refactor: renomear Gestão→Painel, Frota→Veículos, Funcionários→Colaboradores`

Feito quando: `grep -r "Gestão\|Frota\|Funcionários" lib/ test/ docs/` → zero resultados

---

## Tarefa 2 · Criar EmpresaPage com 6 abas

Ficheiro novo: `lib/features/empresa/presentation/empresa_page.dart`

Estrutura: `Scaffold > AppBar("Empresa") > TabBar(6 abas) > Expanded > TabBarView`

Abas:
1. **Dados** — reusar `EmpresaDadosForm` da `CompanySettingsPage`
2. **Regime fiscal** — só leitura do `RegimeFiscal` actual, placeholder "Editar em Dados →"
3. **Custos fixos** — lista editável (Renda, Água+luz, Comunicações, Seguros, Outros) com total; persistir via `updateCompanySettings` com campo por sub-categoria
4. **Veículos** — `VehiclesPage()` encaixada directamente
5. **Finanças** — widget actual de despesas/recebimentos encaixado
6. **Estado** — `Text("Timeline de obrigações fiscais — em preparação para v0.0.8.")`

Commits atómicos:
- `feat: EmpresaPage estrutura + abas Regime e Estado (placeholders)`
- `feat: aba Empresa/Dados via EmpresaDadosForm`
- `feat: aba Empresa/Custos fixos com granularidade`
- `refactor: VehiclesPage e Finanças encaixados em Empresa`

Feito quando: `flutter test` verde, 6 abas renderizam sem overflow
