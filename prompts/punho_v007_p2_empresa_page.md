# v0.0.7 · Passo 2 — Criar EmpresaPage com 6 abas

Estás na branch `feat/v007-sidebar-empresa`. Passo 1 já commitado.

## Ficheiro a criar

`lib/features/empresa/presentation/empresa_page.dart`

## Estrutura exacta

```
Scaffold
  AppBar: título "Empresa"
  Column
    TabBar — 6 abas (ícone + label curto):
      Dados | Regime | Custos fixos | Veículos | Finanças | Estado
    Expanded
      TabBarView — 6 widgets:
```

## Conteúdo de cada aba

1. **Dados** — reutilizar ou extrair `EmpresaDadosForm` da `CompanySettingsPage` actual.
2. **Regime fiscal** — só leitura do `RegimeFiscal` actual. Placeholder "Editar em Dados →" chega.
3. **Custos fixos** — lista editável: Renda, Água+luz, Comunicações, Seguros, Outros. Cada linha: descrição + valor em cêntimos. Total no fim. Persistir via `updateCompanySettings` com campo por sub-categoria.
4. **Veículos** — `VehiclesPage()` directamente (sem navegação nova, só encaixar o widget).
5. **Finanças** — widget actual de despesas/recebimentos encaixado da mesma forma.
6. **Estado** — `Text("Timeline de obrigações fiscais — em preparação para v0.0.8.")`.

## O que não fazer

Não implementar o motor de mudança de regime. Não criar novas rotas aqui (é o Passo 4).

## Commits

1. `feat: EmpresaPage com estrutura de 6 abas`
2. `feat: aba Empresa/Dados via EmpresaDadosForm`
3. `feat: aba Empresa/Custos fixos com granularidade`
4. `refactor: VehiclesPage encaixada em Empresa/Veículos`
5. `refactor: ecrã de Finanças encaixado em Empresa/Finanças`

## Feito quando

`flutter test` verde. As 6 abas renderizam sem overflow.
