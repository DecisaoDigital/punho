import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/format/campos.dart';
import '../../../domain/models/finance.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/empresa_sync/empresa_sync_service.dart';
import '../../../core/session/demo_session.dart';

/// Formas jurídicas oferecidas. As mesmas do onboarding.
const _formasJuridicas = ['Empresário em Nome Individual', 'Lda.'];

/// Definições da empresa: ver e editar tudo o que o onboarding recolheu.
///
/// Antes disto os dados do onboarding entravam e não voltavam a aparecer em
/// lado nenhum — quem escrevia a facturação ou a morada ficava sem forma de
/// confirmar o que tinha escrito, e muito menos de corrigir.
class CompanySettingsPage extends ConsumerStatefulWidget {
  const CompanySettingsPage({super.key, this.embutida = false});

  /// A página vive em dois sítios: como ecrã próprio (navegável, com AppBar) e
  /// como aba **Dados** do destino Empresa. Embutida dispensa o Scaffold e a
  /// AppBar, que de outro modo empilhariam dois cabeçalhos.
  ///
  /// É reutilização e não duplicação: o formulário é o mesmo, com uma só fonte
  /// de verdade sobre o que se pede e como se grava.
  final bool embutida;

  @override
  ConsumerState<CompanySettingsPage> createState() =>
      _CompanySettingsPageState();
}

class _CompanySettingsPageState extends ConsumerState<CompanySettingsPage> {
  late final TextEditingController _ownerName;
  late final TextEditingController _companyName;
  late final TextEditingController _taxId;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _postalCode;
  late final TextEditingController _locality;
  late final TextEditingController _collaborators;
  late final TextEditingController _vehicles;
  late final TextEditingController _machines;
  late final TextEditingController _revenueLastYear;
  late final TextEditingController _revenueThisYear;
  late final TextEditingController _maintenanceLastYear;
  late final TextEditingController _fixedMonthlyCosts;
  late String _legalForm;
  late List<CustoFixo> _custosFixos;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    // Lido uma vez: daqui para a frente manda o formulário, senão uma
    // sincronização a chegar a meio da edição apagava o que se está a escrever.
    final dados = ref.read(operationsProvider);
    _ownerName = TextEditingController(text: dados.ownerName ?? '');
    _companyName = TextEditingController(text: dados.companyName);
    _taxId = TextEditingController(text: dados.companyTaxId ?? '');
    _phone = TextEditingController(text: dados.companyPhone ?? '');
    _email = TextEditingController(text: dados.companyEmail ?? '');
    _address = TextEditingController(text: dados.companyAddress ?? '');
    _postalCode = TextEditingController(text: dados.companyPostalCode ?? '');
    _locality = TextEditingController(text: dados.companyLocality ?? '');
    _collaborators = TextEditingController(
      text: '${dados.declaredCollaboratorCount}',
    );
    _vehicles = TextEditingController(text: '${dados.declaredVehicleCount}');
    _machines = TextEditingController(text: '${dados.totalMachinesDeclared}');
    _revenueLastYear = TextEditingController(
      text: textoDeCents(dados.revenueLastYearCents),
    );
    _revenueThisYear = TextEditingController(
      text: textoDeCents(dados.revenueThisYearCents),
    );
    _maintenanceLastYear = TextEditingController(
      text: textoDeCents(dados.maintenanceLastYearCents),
    );
    _fixedMonthlyCosts = TextEditingController(
      text: textoDeCents(dados.fixedMonthlyCostsCents),
    );
    // Quem só tinha o total redondo entra com ele já convertido numa rubrica
    // "Outros": passa a poder mexer-lhe em vez de olhar para um número opaco.
    _custosFixos = dados.custosFixos.isNotEmpty
        ? List.of(dados.custosFixos)
        : [
            if (dados.fixedMonthlyCostsCents != null)
              CustoFixo(
                id: 'cf-legado',
                categoria: ExpenseCategory.other,
                valorCents: dados.fixedMonthlyCostsCents!,
                descricao: 'Custos fixos (por separar)',
              ),
          ];
    // Dados antigos podem ter uma forma jurídica que já não está na lista; sem
    // isto o Dropdown rebentava por o valor não ter opção correspondente.
    _legalForm = _formasJuridicas.contains(dados.legalForm)
        ? dados.legalForm
        : (dados.legalForm.isEmpty ? _formasJuridicas.first : dados.legalForm);
  }

  @override
  void dispose() {
    for (final controller in [
      _ownerName,
      _companyName,
      _taxId,
      _phone,
      _email,
      _address,
      _postalCode,
      _locality,
      _collaborators,
      _vehicles,
      _machines,
      _revenueLastYear,
      _revenueThisYear,
      _maintenanceLastYear,
      _fixedMonthlyCosts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    ref
        .read(operationsProvider.notifier)
        .updateCompanySettings(
          ownerName: Campo(textoOpcional(_ownerName.text)),
          companyName: _companyName.text,
          legalForm: _legalForm,
          collaborators: contagemDeTexto(_collaborators.text),
          vehicles: contagemDeTexto(_vehicles.text),
          totalMachinesDeclared: contagemDeTexto(_machines.text),
          companyTaxId: Campo(textoOpcional(_taxId.text)),
          companyPhone: Campo(textoOpcional(_phone.text)),
          companyEmail: Campo(textoOpcional(_email.text)),
          companyAddress: Campo(textoOpcional(_address.text)),
          companyPostalCode: Campo(textoOpcional(_postalCode.text)),
          companyLocality: Campo(textoOpcional(_locality.text)),
          revenueLastYearCents: Campo(centsDeTexto(_revenueLastYear.text)),
          revenueThisYearCents: Campo(centsDeTexto(_revenueThisYear.text)),
          maintenanceLastYearCents: Campo(
            centsDeTexto(_maintenanceLastYear.text),
          ),
          // O total redondo deixa de ser escrito: quem manda são as rubricas.
          // Fica a `null` para nunca haver duas respostas à mesma pergunta.
          fixedMonthlyCostsCents: const Campo(null),
          custosFixos: List.of(_custosFixos),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados da empresa guardados.')),
    );
    // Best-effort: envia para o Supabase em background; se falhar, o utilizador
    // pode carregar em "Sincronizar com o Control" mais tarde.
    unawaited(_disparaSyncSilencioso());
    Navigator.of(context).maybePop();
  }

  Future<void> _disparaSyncSilencioso() async {
    final sync = ref.read(empresaSyncProvider);
    if (sync == null) return;
    await sync.sincronizar(_payloadSincronizacao());
  }

  Future<void> _sincronizarAgora() async {
    final sync = ref.read(empresaSyncProvider);
    if (sync == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo demonstração — não há Control para sincronizar.'),
        ),
      );
      return;
    }
    setState(() => _sincronizando = true);
    final ok = await sync.sincronizar(_payloadSincronizacao());
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Dados sincronizados com o Control.'
              : 'Não foi possível sincronizar. Tenta outra vez daqui a pouco.',
        ),
      ),
    );
  }

  /// Payload jsonb enviado à Edge Function `sincronizar-empresa-punho`.
  /// Chaves são as que o trigger DB `punho_empresas_sync_licenca` lê:
  /// `nif` é obrigatório para o trigger criar/actualizar a licença.
  Map<String, dynamic> _payloadSincronizacao() {
    final txt = (String v) => v.trim().isEmpty ? null : v.trim();
    final n = (String v) {
      final s = v.replaceAll(',', '.').trim();
      if (s.isEmpty) return null;
      final d = double.tryParse(s);
      if (d == null) return null;
      return (d * 100).round();
    };
    return {
      'nif': _taxId.text.trim(),
      'nome_comercial': _companyName.text.trim(),
      'forma_juridica': _legalForm,
      'nome_gestor': txt(_ownerName.text),
      'morada': txt(_address.text),
      'codigo_postal': txt(_postalCode.text),
      'localidade': txt(_locality.text),
      'telefone': txt(_phone.text),
      'email': txt(_email.text),
      'n_colaboradores': int.tryParse(_collaborators.text) ?? 0,
      'n_veiculos': int.tryParse(_vehicles.text) ?? 0,
      'n_maquinas': int.tryParse(_machines.text) ?? 0,
      'facturacao_ano_passado_centavos': n(_revenueLastYear.text),
      'facturacao_este_ano_centavos': n(_revenueThisYear.text),
      'manutencao_ano_passado_centavos': n(_maintenanceLastYear.text),
      'custos_fixos_mensais_centavos': n(_fixedMonthlyCosts.text),
    };
  }

  Future<void> _reporDados() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repor dados desta app?'),
        content: const Text(
          'Apaga tudo o que está guardado neste dispositivo — empresa, '
          'máquinas, clientes, reservas, despesas e recebimentos — e volta ao '
          'arranque. Não afecta nada no servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Repor'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    ref.read(operationsProvider.notifier).resetAll();
    if (!mounted) return;
    // A shell volta ao onboarding sozinha assim que `onboarded` fica falso.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_podeEditar(ref)) return const _SoGestor();
    // Embutida numa aba de Empresa, o Scaffold e a AppBar sobram: já há um
    // título por cima. Sem isto ficavam dois cabeçalhos empilhados a dizer
    // quase o mesmo.
    if (widget.embutida) return SafeArea(child: _corpo(context));
    return Scaffold(
      appBar: AppBar(title: const Text('Dados da empresa')),
      body: SafeArea(child: _corpo(context)),
    );
  }

  Widget _corpo(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      Text(
        'Isto é o que indicou no arranque. Pode corrigir e guardar quando '
        'quiser.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      _CardSeccao(
        icone: Icons.badge_outlined,
        titulo: 'Identificação',
        children: [
          _campo(_ownerName, 'Nome do responsável'),
          _campo(_companyName, 'Nome da empresa / nome comercial'),
          DropdownButtonFormField<String>(
            initialValue: _legalForm,
            // Mesma razão do onboarding: a forma jurídica mais longa não
            // cabe e rebentaria a linha.
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Forma jurídica'),
            items: [
              for (final forma in {..._formasJuridicas, _legalForm})
                DropdownMenuItem(value: forma, child: Text(forma)),
            ],
            onChanged: (valor) =>
                setState(() => _legalForm = valor ?? _legalForm),
          ),
          _campo(
            _taxId,
            'NIF da empresa',
            teclado: TextInputType.number,
            ajuda: 'Pode ficar em branco — preenche-se quando souber.',
          ),
        ],
      ),
      _CardSeccao(
        icone: Icons.place_outlined,
        titulo: 'Contactos e morada',
        children: [
          _campo(_phone, 'Telemóvel', teclado: TextInputType.phone),
          _campo(_email, 'Email', teclado: TextInputType.emailAddress),
          _campo(_address, 'Morada'),
          _campo(_postalCode, 'Código-postal'),
          _campo(_locality, 'Localidade'),
        ],
      ),
      _CardSeccao(
        icone: Icons.groups_outlined,
        titulo: 'Equipa e frota',
        children: [
          _campo(
            _collaborators,
            'Colaboradores',
            teclado: TextInputType.number,
            ajuda: 'A zero, a área de Funcionários desaparece do menu.',
          ),
          _campo(
            _vehicles,
            'Veículos',
            teclado: TextInputType.number,
            ajuda: 'A zero, a área de Frota desaparece do menu.',
          ),
          _campo(
            _machines,
            'Máquinas que tem (estimativa)',
            teclado: TextInputType.number,
            ajuda:
                'Serve para o Punho saber quantas faltam identificar no '
                'inventário.',
          ),
        ],
      ),
      _CardSeccao(
        icone: Icons.query_stats_outlined,
        titulo: 'Referências financeiras',
        children: [
          _campo(
            _revenueLastYear,
            'Facturação do ano passado (€)',
            teclado: TextInputType.number,
          ),
          _campo(
            _revenueThisYear,
            'Facturação deste ano até hoje (€)',
            teclado: TextInputType.number,
          ),
          _campo(
            _maintenanceLastYear,
            'Manutenção paga no ano passado (€)',
            teclado: TextInputType.number,
          ),
        ],
      ),
      _CardSeccao(
        icone: Icons.receipt_long_outlined,
        titulo: 'Custos fixos mensais',
        children: [
          _EditorDeCustosFixos(
            rubricas: _custosFixos,
            aoMudar: (novas) => setState(() => _custosFixos = novas),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _guardar,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Guardar'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _sincronizando ? null : _sincronizarAgora,
        icon: _sincronizando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(
          _sincronizando ? 'A sincronizar…' : 'Sincronizar com o Control',
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      const SizedBox(height: 28),
      _CardSeccao(
        icone: Icons.warning_amber_outlined,
        titulo: 'Repor',
        children: [
          const Text(
            'Se este dispositivo tem dados de testes antigos — máquinas '
            'ou clientes que não reconhece — pode apagar tudo e começar '
            'do zero.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reporDados,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Repor dados desta app'),
          ),
        ],
      ),
    ],
  );

  Widget _campo(
    TextEditingController controller,
    String etiqueta, {
    TextInputType? teclado,
    String? ajuda,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: teclado,
      inputFormatters: teclado == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(labelText: etiqueta, helperText: ajuda),
    ),
  );
}

/// Só o gestor edita a empresa.
///
/// Com Supabase ligado quem chega à `AppShell` já é gestor aprovado (decide o
/// `AcessoGate`); sem Supabase, quem manda é o perfil da sessão de
/// demonstração. Verifica-se aqui outra vez porque a página é navegável por si.
bool _podeEditar(WidgetRef ref) =>
    SupabaseConfig.enabled || ref.read(demoSessionProvider).isManager;

class _SoGestor extends StatelessWidget {
  const _SoGestor();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dados da empresa')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Só um gestor pode ver e alterar os dados da empresa.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _CardSeccao extends StatelessWidget {
  const _CardSeccao({
    required this.icone,
    required this.titulo,
    required this.children,
  });

  final IconData icone;
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

/// As rubricas do custo fixo mensal, com o total à vista.
///
/// Substitui um campo único de "Custos fixos mensais (€)". Um total redondo não
/// se revê nem se corrige — quando a renda sobe, o gestor não sabe que parte do
/// número mudar, e o painel não consegue dizer onde apertar.
class _EditorDeCustosFixos extends StatelessWidget {
  const _EditorDeCustosFixos({required this.rubricas, required this.aoMudar});

  final List<CustoFixo> rubricas;
  final ValueChanged<List<CustoFixo>> aoMudar;

  /// As que aparecem primeiro no selector. As restantes continuam lá.
  static const List<ExpenseCategory> _sugeridas = [
    ExpenseCategory.rent,
    ExpenseCategory.electricity,
    ExpenseCategory.water,
    ExpenseCategory.cleaning,
    ExpenseCategory.advertising,
    ExpenseCategory.supplies,
    ExpenseCategory.other,
  ];

  void _acrescentar() {
    aoMudar([
      ...rubricas,
      CustoFixo(
        id: 'cf${DateTime.now().microsecondsSinceEpoch}',
        // Renda é quase sempre a primeira que se lembra, e a maior.
        categoria: rubricas.isEmpty
            ? ExpenseCategory.rent
            : ExpenseCategory.other,
        valorCents: 0,
      ),
    ]);
  }

  void _substituir(int indice, CustoFixo nova) {
    final copia = List.of(rubricas);
    copia[indice] = nova;
    aoMudar(copia);
  }

  void _remover(int indice) {
    final copia = List.of(rubricas)..removeAt(indice);
    aoMudar(copia);
  }

  @override
  Widget build(BuildContext context) {
    final total = totalDeCustosFixos(rubricas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rubricas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Sem rubricas. Enquanto não houver nenhuma, o painel mostra '
              '"Por apurar" em vez de inventar um custo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (var i = 0; i < rubricas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<ExpenseCategory>(
                    initialValue: rubricas[i].categoria,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      for (final categoria in [
                        ..._sugeridas,
                        ...ExpenseCategory.values.where(
                          (c) => !_sugeridas.contains(c),
                        ),
                      ])
                        DropdownMenuItem(
                          value: categoria,
                          child: Text(
                            expenseCategoryLabel(categoria),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        _substituir(i, rubricas[i].copyWith(categoria: valor));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    initialValue: rubricas[i].descricao,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'opcional',
                    ),
                    onChanged: (valor) =>
                        _substituir(i, rubricas[i].copyWith(descricao: valor)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: textoDeCents(rubricas[i].valorCents),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '€ / mês'),
                    onChanged: (valor) => _substituir(
                      i,
                      rubricas[i].copyWith(
                        valorCents: centsDeTexto(valor) ?? 0,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover rubrica',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remover(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _acrescentar,
            icon: const Icon(Icons.add),
            label: const Text('Acrescentar rubrica'),
          ),
        ),
        if (total != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Total: ${textoDeCents(total)} € por mês',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}
