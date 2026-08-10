import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/brand_lockup.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/empresa_sync/empresa_sync_controller.dart';
import '../../../core/empresa_sync/ficha_da_empresa.dart';
import '../../../core/format/campos.dart';
import '../../../core/layout/ecra_de_formulario.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/theme/punho_theme.dart';
import '../../../core/media/machine_image_store.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/operations/preco_da_reserva.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/session/demo_session.dart';
import '../../../data/repositories/operation_repository.dart';
import '../../../domain/models/operations.dart';
import '../../../domain/models/historical_month.dart';
import '../../auth/acesso_providers.dart';
import '../../auth/domain/estado_acesso.dart';
import 'bem_vindo_screen.dart';
import 'boas_vindas_screen.dart';
import 'mais_dados_screen.dart';
import 'rascunho_do_onboarding.dart';

/// Os ecrãs do onboarding que explicam em vez de pedir.
enum _EcraDeContexto { bemVindo, maisDados, boasVindas }

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with WidgetsBindingObserver {
  int step = 0, collaborators = 0, machines = 0, vehicles = 0;
  // Se o gestor não quer/não tem tempo agora, salta os passos financeiros e
  // operacionais (máquinas + facturação + manutenção + custos).
  // A ideia é deixá-lo entrar na app cedo e ganhar confiança primeiro.
  bool wantsFullSetup = true;
  String legal = 'Empresário em Nome Individual';
  // fleet fica derivado de vehicles > 0 na hora de gravar (para não mudar
  // o contrato de completeOnboarding).
  // Cargo declarado pelo utilizador logo no início do onboarding.
  // Em modo demo o valor fica só no state (não bloqueia nada por agora).
  // Quando a app for para Supabase real, o cargo autoritativo vem de
  // punho_membros — este é ignorado ou usado só como sugestão.
  String role = 'gestor';
  final ownerName = TextEditingController();
  final name = TextEditingController();
  final taxId = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final postalCode = TextEditingController();
  final locality = TextEditingController();
  final revenueLastYear = TextEditingController();
  final revenueThisYear = TextEditingController();
  final maintenanceLastYear = TextEditingController();
  final fixedMonthlyCosts = TextEditingController();
  // Erro inline do passo do NIF. Decisão do Cesar: o NIF passa a obrigatório
  // no onboarding — deixou de poder ficar como "tarefa aberta". A Edge
  // Function `sincronizar-empresa-punho` sempre rejeitou (400, payload
  // inteiro) empresas com `nif.length < 9`, e a ficha ficava presa para
  // sempre em `punho_empresas.dados={}`. Isto fecha a porta na origem.
  String? nifErro;

  /// Passos que **não se voltam a perguntar** porque já foram respondidos no
  /// pedido de acesso — índices em `titlesFull`/`titlesColab`.
  ///
  /// Vazio quando o servidor não sabe nada (modo de demonstração, ou conta sem
  /// pedido): aí pergunta-se tudo, como sempre.
  final _jaRespondidos = <int>{};

  /// Quem entra, quando o servidor já o sabe — ou seja, quando o pedido foi
  /// aprovado. Nulo em modo de demonstração, e é ele que decide se há ecrã de
  /// boas-vindas.
  String? _nomeConhecido;

  static const _passoNome = 0, _passoEmpresa = 1, _passoCargo = 2;

  /// Passos do gestor que a ordem pedida a 5/8/2026 mexeu, com nome para não
  /// haver números soltos espalhados: o NIF valida-se, o dos funcionários leva
  /// nota de rodapé, e o do switch é a fronteira do caminho curto.
  static const _passoNif = 3, _passoFuncionarios = 4, _passoDoSwitch = 8;

  /// Acima disto, o passo dos funcionários avisa — não recusa.
  ///
  /// «se passar de 3, uma nota de rodapé: limite temporário de máx. 3
  /// funcionários, fale com a Decisão Digital para desbloquear mais» — Cesar,
  /// 5/8/2026. É um tecto de produto, temporário e igual para todos os que
  /// entram; o limite a sério de cada empresa é o que ele autoriza no Control
  /// (`punho_subscricoes.limite_colaboradores_ativos`), e no onboarding ainda
  /// não há subscrição para o ler. Nada aqui bloqueia: o número declarado é
  /// informativo, e quem trava o acesso de quem excede é a aprovação no
  /// Control.
  static const _funcionariosSemAutorizacao = 3;

  @override
  void initState() {
    super.initState();
    // Portrait em todos os passos. O Cesar apanhou o passo 4 deitado num
    // tablet: o `main.dart` bloqueava landscape no arranque e ninguém aqui
    // dizia o contrário (Decisão 13).
    OrientacaoDoContexto.portraitJa();
    // Para saber quando a app vai para segundo plano — é o último momento em
    // que ainda se pode gravar o rascunho antes de o sistema matar o processo.
    WidgetsBinding.instance.addObserver(this);
    _preencherComOQueOServidorJaSabe();
    _recuperarRascunho();
  }

  /// O papel de rascunho, quando as [SharedPreferences] já responderam.
  ///
  /// `null` até lá e em modo de teste sem plugin — e nesse caso o onboarding
  /// funciona exactamente como funcionava, sem guardar nada.
  RascunhoDoOnboarding? _rascunho;

  /// Traz de volta o que ficou escrito da última vez.
  ///
  /// Corre depois de [_preencherComOQueOServidorJaSabe] de propósito: o que o
  /// próprio escreveu ganha ao que o servidor sabia, porque é mais recente e
  /// porque pode ter sido uma correcção.
  Future<void> _recuperarRascunho() async {
    RascunhoDoOnboarding rascunho;
    try {
      rascunho = RascunhoDoOnboarding(await SharedPreferences.getInstance());
    } catch (erro) {
      // Sem armazenamento não se guarda rascunho nenhum. É uma perda de
      // conforto, não é motivo para não deixar entrar na app.
      debugPrint('[Onboarding] sem rascunho: $erro');
      return;
    }
    if (!mounted) return;
    _rascunho = rascunho;
    final guardado = rascunho.ler();
    if (guardado == null) return;
    setState(() => _aplicarRascunho(guardado));
  }

  void _aplicarRascunho(Map<String, dynamic> r) {
    void texto(TextEditingController controlador, String chave) {
      final valor = r[chave];
      if (valor is String && valor.isNotEmpty) controlador.text = valor;
    }

    int numero(String chave, int actual) =>
        (r[chave] as num?)?.toInt() ?? actual;

    texto(ownerName, 'nome');
    texto(name, 'empresa');
    texto(taxId, 'nif');
    texto(phone, 'telefone');
    texto(email, 'email');
    texto(address, 'morada');
    texto(postalCode, 'codigo_postal');
    texto(locality, 'localidade');
    texto(revenueLastYear, 'faturacao_ano_passado');
    texto(revenueThisYear, 'faturacao_este_ano');
    texto(maintenanceLastYear, 'manutencao');
    texto(fixedMonthlyCosts, 'custos_fixos');
    if (r['cargo'] is String) role = r['cargo'] as String;
    if (r['forma_juridica'] is String) legal = r['forma_juridica'] as String;
    if (r['quer_tudo'] is bool) wantsFullSetup = r['quer_tudo'] as bool;
    collaborators = numero('funcionarios', collaborators);
    vehicles = numero('veiculos', vehicles);
    machines = numero('maquinas', machines);
    // Volta ao passo onde ia. Se o percurso entretanto encolheu — outra conta,
    // outro cargo —, o `build` corta-o para o último que existe.
    step = numero('passo', step);
  }

  /// O formulário inteiro, tal como está agora.
  Map<String, dynamic> _paraRascunho() => {
    'passo': step,
    'cargo': role,
    'forma_juridica': legal,
    'quer_tudo': wantsFullSetup,
    'funcionarios': collaborators,
    'veiculos': vehicles,
    'maquinas': machines,
    'nome': ownerName.text,
    'empresa': name.text,
    'nif': taxId.text,
    'telefone': phone.text,
    'email': email.text,
    'morada': address.text,
    'codigo_postal': postalCode.text,
    'localidade': locality.text,
    'faturacao_ano_passado': revenueLastYear.text,
    'faturacao_este_ano': revenueThisYear.text,
    'manutencao': maintenanceLastYear.text,
    'custos_fixos': fixedMonthlyCosts.text,
  };

  /// Guarda sem esperar: isto não pode atrasar uma mudança de ecrã.
  void _guardarRascunho() {
    final rascunho = _rascunho;
    if (rascunho == null) return;
    unawaited(rascunho.guardar(_paraRascunho()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // `paused` é o último aviso antes de o Android poder terminar o processo —
    // e o MIUI termina-o sem cerimónia. É aqui que o que está escrito no ecrã
    // actual fica em segurança.
    if (estado == AppLifecycleState.paused) _guardarRascunho();
  }

  /// Os três primeiros passos — nome, empresa, cargo — são exactamente o que o
  /// pedido de acesso já perguntou e o Control já aprovou. Guarda-se a resposta
  /// e **tira-se a pergunta do percurso**.
  ///
  /// «quando eu fiz log in já foi pedido isto, se já foi perguntado e já
  /// respondi, não tem de me fazer mais estas perguntas» — César, 5/8/2026.
  /// Tinha acabado de ser aprovado como Alfredo/DepilConcept e o Punho abriu em
  /// «Como te chamas?». Trazer a resposta já escrita no campo não chegava: a
  /// pergunta continuava lá, e uma pergunta já respondida não é para fazer.
  ///
  /// O que **não** se faz é dar o onboarding por concluído: o NIF, a morada, a
  /// equipa e os números continuam por dizer, e é para isso que os outros
  /// passos existem. Tiram-se os respondidos, ficam os que faltam.
  void _preencherComOQueOServidorJaSabe() {
    // Em modo de demonstração não há Supabase, e `Supabase.instance` rebenta.
    // Um onboarding que não arranca é muito pior do que um campo por preencher.
    EstadoAcesso? acesso;
    try {
      acesso = ref.read(estadoAcessoProvider).valueOrNull;
    } catch (_) {
      return;
    }
    if (acesso == null) return;
    if (acesso.nome != null) {
      ownerName.text = acesso.nome!;
      _nomeConhecido = acesso.nome;
      _jaRespondidos.add(_passoNome);
    }
    if (acesso.empresaNome != null) {
      name.text = acesso.empresaNome!;
      _jaRespondidos.add(_passoEmpresa);
    }
    // O cargo autoritativo é o de `punho_membros`, como o comentário de [role]
    // já dizia que havia de ser assim que houvesse Supabase a sério. Deixa de
    // ser uma pergunta: quem responde é o Control, ao aprovar.
    if (acesso.perfil != null) {
      role = acesso.perfil!;
      _jaRespondidos.add(_passoCargo);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [
      name,
      ownerName,
      taxId,
      phone,
      email,
      address,
      postalCode,
      locality,
      revenueLastYear,
      revenueThisYear,
      maintenanceLastYear,
      fixedMonthlyCosts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Grava tudo e entra na app.
  ///
  /// Saiu de dentro do botão "Continuar" para poder ser chamado pelo
  /// [BoasVindasScreen], que é agora o único sítio de onde se grava. O `step` já
  /// não avança depois disto, portanto não há caminho para o chamar duas vezes:
  /// o ecrã seguinte é a app.
  void _concluirOnboarding() {
    // O rascunho existe para o caminho até aqui. A partir deste ponto a
    // verdade é o `OperationsState`, e deixá-lo para trás fazia a próxima
    // conta a entrar neste telemóvel herdar respostas que não são dela.
    unawaited(_rascunho?.limpar() ?? Future.value());
    ref
        .read(operationsProvider.notifier)
        .completeOnboarding(
          ownerName: _optional(ownerName.text),
          companyName: name.text.trim().isEmpty
              ? 'A minha empresa'
              : name.text.trim(),
          legalForm: legal,
          hasFleet: vehicles > 0,
          declaredVehicleCount: vehicles,
          collaborators: collaborators,
          totalMachinesDeclared: machines,
          // Sempre false: o passo "inserir máquinas agora" foi removido. O
          // utilizador adiciona máquinas em detalhe (foto, referência) na secção
          // Máquinas ao seu ritmo.
          insertMachinesNow: false,
          companyTaxId: _optional(taxId.text),
          companyPhone: _optional(phone.text),
          companyEmail: _optional(email.text),
          companyAddress: _optional(address.text),
          companyPostalCode: _optional(postalCode.text),
          companyLocality: _optional(locality.text),
          revenueLastYearCents: centsDeTexto(revenueLastYear.text),
          revenueThisYearCents: centsDeTexto(revenueThisYear.text),
          maintenanceLastYearCents: centsDeTexto(maintenanceLastYear.text),
          fixedMonthlyCostsCents: centsDeTexto(fixedMonthlyCosts.text),
        );
    // Best-effort e invisível, como em Definições da Empresa: sem isto a
    // ficha só chegava ao servidor se o gestor mais tarde abrisse Definições
    // e carregasse em Guardar — e até lá a empresa aparecia no Control sem
    // NIF e sem nome. Fica pendente e o `EmpresaSyncController` insiste
    // sozinho de 20 em 20 minutos; se falhar (sem rede, sem Supabase, modo
    // demonstração), o onboarding termina na mesma — nada bloqueia aqui.
    final payload = _payloadSincronizacaoOnboarding();
    if (payload != null) {
      unawaited(
        ref
            .read(empresaSyncControllerProvider.notifier)
            .atualizarFicha(payload),
      );
    }
  }

  /// A ficha da empresa tal como o onboarding a recolheu, pronta a enviar.
  ///
  /// `null` para o colaborador: ele não preenche NIF, morada nem números da
  /// empresa (não lhe é sequer pedido — ver `titlesColab`), e mandar isto em
  /// branco apagava a ficha real de quem já a tinha preenchido.
  Map<String, dynamic>? _payloadSincronizacaoOnboarding() {
    if (role == 'colaborador') return null;
    return FichaDaEmpresa(
      nif: _optional(taxId.text),
      nomeComercial: name.text.trim().isEmpty
          ? 'A minha empresa'
          : name.text.trim(),
      formaJuridica: legal,
      nomeGestor: _optional(ownerName.text),
      morada: _optional(address.text),
      codigoPostal: _optional(postalCode.text),
      localidade: _optional(locality.text),
      telefone: _optional(phone.text),
      email: _optional(email.text),
      nColaboradores: collaborators,
      nVeiculos: vehicles,
      nMaquinas: machines,
      facturacaoAnoPassadoCentavos: centsDeTexto(revenueLastYear.text),
      facturacaoEsteAnoCentavos: centsDeTexto(revenueThisYear.text),
      manutencaoAnoPassadoCentavos: centsDeTexto(maintenanceLastYear.text),
      custosFixosMensaisCentavos: centsDeTexto(fixedMonthlyCosts.text),
    ).paraPayload();
  }

  @override
  Widget build(BuildContext context) {
    // Fluxo:
    //   0 - nome do utilizador
    //   1 - nome da empresa
    //   2 - cargo (gestor / colaborador)
    //   [se colaborador termina aqui — não sabe nem tem de saber NIF, morada,
    //    facturação ou custos da empresa. Isso é do gestor.]
    //   3+ - só para gestor: dados administrativos + operacionais
    // A ordem dos três primeiros passos do gestor foi dada pelo Cesar a 5 de
    // Agosto de 2026, depois de ver o ecrã de boas-vindas: «depois do Bem-vindo
    // pedes o contribuinte, o número de funcionários e se existem veículos da
    // empresa e quantos». São os três que dão o painel a mexer — quem é a
    // empresa perante o fisco, quanta gente tem e se tem frota. A morada e os
    // contactos passaram para trás deles: são precisos para documentos, não
    // para números, e nenhum ecrã fica à espera deles.
    //
    // Equipa e frota deixaram de partilhar um ecrã pela mesma razão: ele
    // enumerou-os como duas perguntas, e a de funcionários ganhou uma nota de
    // rodapé que não tem nada a ver com veículos.
    const titlesFull = [
      'Como te chamas?',
      'Como se chama a empresa?',
      'Qual é o teu cargo?',
      'Forma jurídica e NIF da empresa',
      'Quantos funcionários tem a empresa?',
      'A empresa tem veículos? Quantos?',
      'Contacto:',
      'Morada da empresa',
      'Continuar com os dados operacionais?',
      'Quantas máquinas tem aproximadamente?',
      'Quanto faturou no ano passado?',
      'Quanto faturou este ano até hoje?',
      'Quanto gastou em manutenção no ano passado?',
      'Quais são os custos fixos mensais?',
    ];
    // Critério dos sub-textos, depois do smoke da v0.0.5: só existe se **ajudar
    // a preencher aquele campo** — formato esperado, o que conta, o que
    // acontece se ficar vazio. Filosofia do produto, missão e "no próximo ecrã
    // vamos…" saem. O Cesar leu o antigo primeiro sub-texto ("O Punho orienta a
    // pessoa responsável por decidir e agir na empresa") a seguir a "Como te
    // chamas?" e a reacção foi: "que raio de frase é aquela?". Era o pitch, não
    // era ajuda.
    //
    // String vazia = sem sub-texto; o widget colapsa em vez de abrir buraco.
    const helpsFull = [
      '',
      '',
      'O gestor decide e vê tudo. O colaborador só regista o seu próprio trabalho.',
      'A forma jurídica pode ser alterada mais tarde. O NIF é obrigatório: 9 dígitos, sem espaços nem pontos.',
      'Quantos trabalham contigo neste momento. Pode ser 0. O separador Funcionários fica activo quando for maior que 0.',
      'Carrinhas, carros ou motas ao serviço da empresa. Pode ser 0 — o separador Veículos só aparece quando for maior que 0.',
      'Telemóvel e email da empresa. É por aqui que te chegamos, e é o que sai nos documentos que envias.',
      'Morada, código-postal e localidade. Não é pedido país.',
      'Podes saltar e preencher depois, em Definições. Sem estes números o painel mostra "Por apurar" em vez de recomendações.',
      'Uma estimativa chega. Criamos uma linha por máquina para lhes dares nome e foto aos poucos.',
      'Um número redondo serve. Fica em branco se não souberes.',
      'O acumulado deste ano até hoje.',
      'Avarias e revisões pagas no ano passado. Uma estimativa chega.',
      'Renda, eletricidade, água, seguros, programas e outros custos que se repetem todos os meses.',
    ];
    // Colaborador: 4 passos (nome, empresa, cargo, contacto telefónico
    // pessoal — para o gestor o poder contactar). O resto — dados fiscais,
    // faturação, custos — é responsabilidade do gestor, não é sequer pedido.
    const titlesColab = [
      'Como te chamas?',
      'Como se chama a empresa?',
      'Qual é o teu cargo?',
      'Qual é o teu contacto telefónico?',
    ];
    const helpsColab = [
      '',
      '',
      'O gestor decide e vê tudo. O colaborador só regista o seu próprio trabalho.',
      'O gestor precisa deste contacto para te chegar quando for preciso.',
    ];
    // Gestor que declarou não ter tempo agora: termina no próprio switch
    // (índice 7), sem entrar nos campos financeiros. Fica lá para preencher
    // depois, na secção Gestão. O corte é `switch + 1` — se um passo entrar ou
    // sair antes dele, é este número que muda.
    final gestorTitles = wantsFullSetup
        ? titlesFull
        : titlesFull.sublist(0, _passoDoSwitch + 1);
    final gestorHelps = wantsFullSetup
        ? helpsFull
        : helpsFull.sublist(0, _passoDoSwitch + 1);
    final titles = role == 'colaborador' ? titlesColab : gestorTitles;
    final helps = role == 'colaborador' ? helpsColab : gestorHelps;

    // O percurso é uma lista de ecrãs, não aritmética sobre um índice: os ecrãs
    // de contexto entram no meio dos passos de dados e as contas de "+1 aqui,
    // −1 ali" tornavam-se impossíveis de ler. Um `int` é um passo de dados (o
    // índice em titles/helps); um `_EcraDeContexto` é um ecrã que explica.
    // Os passos que ainda são perguntas. Os que o pedido de acesso já
    // respondeu saem daqui — a resposta ficou guardada no `initState`, e
    // repetir a pergunta a quem acabou de a responder é o que o César apanhou
    // a 5/8/2026. Índices originais, para o `switch` de baixo e o `i == 6` do
    // ecrã de contexto continuarem a falar da mesma coisa.
    final passosDeDados = [
      for (var i = 0; i < titles.length; i++)
        if (!_jaRespondidos.contains(i)) i,
    ];
    final percurso = <Object>[
      // Quem chega aqui depois de o pedido ser aprovado nunca viu a app: é
      // apresentada antes de lhe ser pedido o NIF. Só quando se sabe o nome —
      // ou seja, só quando houve aprovação; em demonstração não aparece.
      if (_nomeConhecido != null) _EcraDeContexto.bemVindo,
      for (final i in passosDeDados) ...[
        i,
        // Depois do switch, e só quando ele está ligado: o gestor acabou de
        // dizer "sim, quero preencher" e merece saber o que vem.
        if (role != 'colaborador' && wantsFullSetup && i == _passoDoSwitch)
          _EcraDeContexto.maisDados,
      ],
      // Ao colaborador não se mostra: o ecrã promete um painel que o shell dele
      // não tem, e pede uma rotação que o shell dele não faz.
      if (role != 'colaborador') _EcraDeContexto.boasVindas,
    ];
    // O `step` é um índice no percurso, e o switch abaixo continua a indexar os
    // passos de dados. Fora de um passo de dados fica −1, que nenhum `case`
    // apanha, e o ecrã de contexto é devolvido antes de o `input` ser usado.
    //
    // O corte não é decoração: o percurso encolhe quando se desliga o switch, e
    // um rascunho recuperado pode apontar para além do fim. Corrige-se o `step`
    // e não só a leitura — senão o "Voltar" seguinte recuava a partir de um
    // número que já não existe.
    final passo = step.clamp(0, percurso.length - 1);
    if (passo != step) step = passo;
    final ecraActual = percurso[passo];
    final passoDeDados = ecraActual is int ? ecraActual : -1;

    if (ecraActual is _EcraDeContexto) {
      void voltar() => _irPara(passo - 1);
      return _comBotaoParaTras(passo, switch (ecraActual) {
        _EcraDeContexto.bemVindo => BemVindoScreen(
          nome: _nomeConhecido!,
          aoAvancar: () => _irPara(passo + 1),
        ),
        _EcraDeContexto.maisDados => MaisDadosScreen(
          aoAvancar: () => _irPara(passo + 1),
          aoVoltar: voltar,
        ),
        _EcraDeContexto.boasVindas => BoasVindasScreen(
          aoEntrar: _concluirOnboarding,
          aoVoltar: voltar,
        ),
      });
    }

    final input = switch (passoDeDados) {
      0 => TextField(
        controller: ownerName,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nome',
          border: OutlineInputBorder(),
        ),
      ),
      1 => TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome da empresa',
          border: OutlineInputBorder(),
        ),
      ),
      2 => DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: role,
        decoration: const InputDecoration(
          labelText: 'O teu cargo',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
          DropdownMenuItem(value: 'colaborador', child: Text('Colaborador')),
        ],
        onChanged: (v) => setState(() => role = v ?? 'gestor'),
      ),
      // Passo 3 ramifica pelo cargo:
      //   colaborador → contacto pessoal (último passo dele)
      //   gestor → forma jurídica + NIF juntos (menos ecrãs para dados que
      //   pertencem ao mesmo bloco administrativo)
      3 =>
        role == 'colaborador'
            ? TextField(
                controller: phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telemóvel',
                  border: OutlineInputBorder(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: legal,
                    // "Empresário em Nome Individual" não cabe na largura do
                    // cartão de onboarding e rebentava a linha em 52 px. Com
                    // isExpanded o texto encurta com reticências.
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Forma jurídica',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Empresário em Nome Individual',
                        child: Text('Empresário em Nome Individual'),
                      ),
                      DropdownMenuItem(value: 'Lda.', child: Text('Lda.')),
                    ],
                    onChanged: (v) => setState(() => legal = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taxId,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    onChanged: (_) {
                      if (nifErro != null) setState(() => nifErro = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'NIF da empresa',
                      border: const OutlineInputBorder(),
                      errorText: nifErro,
                    ),
                  ),
                ],
              ),
      // Passo 4 (só gestor): quantos funcionários. Sozinho no ecrã porque é o
      // único que tem um tecto a comunicar — ver [_NotaDeRodape] abaixo.
      _passoFuncionarios => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _NumberChoice(
            label: 'Funcionários',
            value: collaborators,
            onChanged: (v) => setState(() => collaborators = v),
          ),
          if (collaborators > _funcionariosSemAutorizacao) ...[
            const SizedBox(height: 12),
            const _NotaDeRodape(
              'Limite temporário de $_funcionariosSemAutorizacao '
              'funcionários. Fale com a Decisão Digital para desbloquear '
              'mais. Pode continuar — os que passarem do limite cadastram-se '
              'à mesma, só não acedem sem autorização.',
            ),
          ],
        ],
      ),
      // Passo 5 (só gestor): frota. O número responde às duas metades da
      // pergunta — se tem, e quantos. Deixou de ser um switch quando passou a
      // servir também para calcular custos.
      5 => _NumberChoice(
        label: 'Veículos',
        value: vehicles,
        onChanged: (v) => setState(() => vehicles = v),
      ),
      // Passo 6 (só gestor): como se lhe chega. Saiu do ecrã da morada por
      // pedido do Cesar a 5/8/2026 — «quero que perguntes o contacto no
      // primeiro log in». Estava lá, mas em quarto e quinto campo de um ecrã
      // com cinco: um dado que se pede não é o mesmo que um dado que está
      // algures no formulário. De caminho, o ecrã da morada deixou de ser o
      // que rebentava com o teclado aberto.
      6 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telemóvel ou telefone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      // Passo 7 (só gestor): a morada, agora só ela.
      7 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: address,
            decoration: const InputDecoration(
              labelText: 'Morada',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: postalCode,
                  decoration: const InputDecoration(
                    labelText: 'Código-postal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: locality,
                  decoration: const InputDecoration(
                    labelText: 'Localidade',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // Passo 8 (só gestor): switch de decisão. Se OFF, `titles` corta aqui
      // e o botão passa a "Começar" — o utilizador entra na app sem preencher
      // máquinas/faturação/custos.
      // Cor verde no thumb+track quando ON: torna claro visualmente que a
      // opção "sim, preencher" está seleccionada. Cinza (default) para OFF.
      _passoDoSwitch => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          wantsFullSetup
              ? 'Sim, quero preencher agora'
              : 'Não, entro na app e preencho depois',
        ),
        value: wantsFullSetup,
        activeThumbColor: Colors.green.shade600,
        activeTrackColor: Colors.green.shade200,
        onChanged: (v) => setState(() => wantsFullSetup = v),
      ),
      9 => _NumberChoice(
        label: 'Número aproximado de máquinas',
        value: machines,
        onChanged: (v) => setState(() => machines = v),
      ),
      10 => _EuroInput(
        controller: revenueLastYear,
        label: 'Faturação no ano passado (€)',
      ),
      11 => _EuroInput(
        controller: revenueThisYear,
        label: 'Faturação deste ano até hoje (€)',
      ),
      12 => _EuroInput(
        controller: maintenanceLastYear,
        label: 'Manutenção paga no ano passado (€)',
      ),
      // Custos fixos é o último passo do onboarding completo — daqui vai
      // directo para a app, sem passar por "quer inserir máquinas agora?".
      // O utilizador adiciona máquinas em detalhe na secção Máquinas quando
      // quiser (assim não é forçado a fazê-lo já no onboarding).
      _ => _EuroInput(
        controller: fixedMonthlyCosts,
        label: 'Custos fixos mensais (€)',
      ),
    };
    return _comBotaoParaTras(
      passo,
      Scaffold(
        // Centrado enquanto couber, a rolar quando não couber.
        //
        // O passo com mais campos — morada, código-postal, localidade, telemóvel
        // e email — não cabe no que sobra do ecrã com o teclado aberto, e a
        // `Column` rebentava por baixo em vez de deixar chegar lá. O `minHeight`
        // é o que mantém o `Center` a centrar: sem ele o scroll dá altura
        // infinita ao filho e o conteúdo colava-se ao topo em todos os passos.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricoes) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: restricoes.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandLockup(),
                          const SizedBox(height: 28),
                          // Conta passos de dados, não ecrãs: os de contexto não têm
                          // contador, e dizer "12 de 14" num percurso cujo contador nunca
                          // chega a 14 era pior do que não o ter.
                          // Conta pelos passos que restam, não pelo índice
                          // original: com as perguntas já respondidas fora, "4 de
                          // 12" seria mentira nos dois números.
                          Text(
                            '${passosDeDados.indexOf(passoDeDados) + 1}'
                            ' de ${passosDeDados.length}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            titles[passoDeDados],
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          // Sub-texto vazio colapsa de facto: sem isto ficava um
                          // SizedBox fantasma a abrir buraco entre a pergunta e o campo.
                          if (helps[passoDeDados].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(helps[passoDeDados]),
                          ],
                          const SizedBox(height: 24),
                          // **Uma chave por passo, e é por causa do teclado.**
                          //
                          // Os passos são todos `Column` com um `TextField` à
                          // cabeça, na mesma posição da árvore. Sem chave, o
                          // Flutter reaproveita o elemento: o campo muda de
                          // controlador e de rótulo, mas a ligação ao teclado
                          // do sistema é a que já estava aberta — e o passo do
                          // contacto abre-a com `TextInputType.phone`. Escrevia-
                          // -se «Morada da empresa» num teclado de marcar
                          // números (visto no Redmi a 10 de Agosto de 2026).
                          //
                          // Aqui e não em cada campo: assim o passo que alguém
                          // acrescentar amanhã já nasce com o teclado dele.
                          KeyedSubtree(
                            key: ValueKey('passo-$passoDeDados'),
                            child: input,
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              if (passo > 0)
                                TextButton(
                                  onPressed: () => _irPara(passo - 1),
                                  child: const Text('Voltar'),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () {
                                  // Passo 3 (só gestor): forma jurídica + NIF. O NIF é
                                  // obrigatório para avançar — ver comentário em
                                  // `nifErro` para o porquê.
                                  if (passoDeDados == _passoNif &&
                                      role != 'colaborador' &&
                                      !nifValido(taxId.text)) {
                                    setState(
                                      () => nifErro =
                                          'O NIF é obrigatório: 9 dígitos.',
                                    );
                                    return;
                                  }
                                  if (passo < percurso.length - 1) {
                                    _irPara(passo + 1);
                                  } else {
                                    // Só o colaborador chega aqui como último ecrã: o
                                    // percurso do gestor termina sempre no ecrã de
                                    // boas-vindas, e é ele que grava.
                                    _concluirOnboarding();
                                  }
                                },
                                child: Text(
                                  passo == percurso.length - 1
                                      ? 'Começar'
                                      : 'Continuar',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Muda de ecrã e deixa o rascunho a par.
  ///
  /// Gravar aqui e não a cada tecla é de propósito: o que interessa não perder
  /// é um passo terminado. O que estiver a ser escrito neste momento fica
  /// seguro pelo [didChangeAppLifecycleState], que dispara quando a app sai
  /// para segundo plano.
  void _irPara(int destino) {
    setState(() => step = destino);
    _guardarRascunho();
  }

  /// O "para trás" do Android recua um passo, como o botão Voltar.
  ///
  /// Não recuava: saía do onboarding inteiro. O Cesar estava a meio dos dados
  /// da empresa, carregou para trás, foi parar ao ecrã inicial do telemóvel e
  /// perdeu o que tinha escrito — «só deveria ter ido uma página para trás».
  ///
  /// No primeiro ecrã deixa-se sair, que é o que o Android manda: aí não há
  /// passo nenhum atrás, e prender a pessoa dentro da app era pior.
  Widget _comBotaoParaTras(int passo, Widget filho) => PopScope(
    canPop: passo == 0,
    onPopInvokedWithResult: (saiu, _) {
      if (saiu || passo == 0) return;
      _irPara(passo - 1);
    },
    child: filho,
  );
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _EuroInput extends StatelessWidget {
  const _EuroInput({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    // Foco imediato para o utilizador escrever logo sem ter de tocar primeiro
    // no campo. Como o input é o único widget do passo, não há ambiguidade.
    autofocus: true,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Ex.: 35000',
      suffixText: '€',
      border: const OutlineInputBorder(),
    ),
  );
}

/// Nota que aparece por baixo do campo quando há algo a dizer sobre a resposta
/// que acabou de ser dada — e só então.
///
/// Não é um erro e não veste a cor de erro: o passo continua a avançar. É um
/// aviso do que vai acontecer a seguir, e a diferença tem de se ver.
class _NotaDeRodape extends StatelessWidget {
  const _NotaDeRodape(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cor),
          ),
        ),
      ],
    );
  }
}

class _NumberChoice extends StatelessWidget {
  const _NumberChoice({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$value'),
      IconButton(
        onPressed: () => onChanged(value + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class InitialDataTasksPage extends ConsumerStatefulWidget {
  const InitialDataTasksPage({super.key});

  @override
  ConsumerState<InitialDataTasksPage> createState() =>
      _InitialDataTasksPageState();
}

class _InitialDataTasksPageState extends ConsumerState<InitialDataTasksPage> {
  late final TextEditingController ownerName;
  late final TextEditingController taxId;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController address;
  late final TextEditingController postalCode;
  late final TextEditingController locality;
  late final TextEditingController revenueLastYear;
  late final TextEditingController revenueThisYear;
  late final TextEditingController maintenanceLastYear;
  late final TextEditingController fixedMonthlyCosts;

  @override
  void initState() {
    super.initState();
    final data = ref.read(operationsProvider);
    ownerName = TextEditingController(text: data.ownerName ?? '');
    taxId = TextEditingController(text: data.companyTaxId ?? '');
    phone = TextEditingController(text: data.companyPhone ?? '');
    email = TextEditingController(text: data.companyEmail ?? '');
    address = TextEditingController(text: data.companyAddress ?? '');
    postalCode = TextEditingController(text: data.companyPostalCode ?? '');
    locality = TextEditingController(text: data.companyLocality ?? '');
    revenueLastYear = TextEditingController(
      text: _euros(data.revenueLastYearCents),
    );
    revenueThisYear = TextEditingController(
      text: _euros(data.revenueThisYearCents),
    );
    maintenanceLastYear = TextEditingController(
      text: _euros(data.maintenanceLastYearCents),
    );
    fixedMonthlyCosts = TextEditingController(
      text: _euros(data.fixedMonthlyCostsCents),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      taxId,
      ownerName,
      phone,
      email,
      address,
      postalCode,
      locality,
      revenueLastYear,
      revenueThisYear,
      maintenanceLastYear,
      fixedMonthlyCosts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(operationsProvider).initialDataTasks;
    return Scaffold(
      appBar: AppBar(title: const Text('Dados por completar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sem estes dados, o Punho não deve tirar conclusões definitivas. Pode preencher por etapas e guardar quando quiser.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${pending.length} tarefas abertas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final task in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $task'),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoricalDataPage()),
              ),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Preencher histórico mensal'),
            ),
            const SizedBox(height: 24),
            Text(
              'Identificação da empresa',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do empresário ou responsável',
              ),
            ),
            TextField(
              controller: taxId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIF da empresa'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel ou telefone',
              ),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Morada'),
            ),
            TextField(
              controller: postalCode,
              decoration: const InputDecoration(labelText: 'Código-postal'),
            ),
            TextField(
              controller: locality,
              decoration: const InputDecoration(labelText: 'Localidade'),
            ),
            const SizedBox(height: 24),
            Text(
              'Referências para orientar a gestão',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pode usar valores redondos. Não é uma declaração fiscal.',
            ),
            const SizedBox(height: 8),
            _EuroInput(
              controller: revenueLastYear,
              label: 'Faturação no ano passado (€)',
            ),
            _EuroInput(
              controller: revenueThisYear,
              label: 'Faturação deste ano até hoje (€)',
            ),
            _EuroInput(
              controller: maintenanceLastYear,
              label: 'Manutenção paga no ano passado (€)',
            ),
            _EuroInput(
              controller: fixedMonthlyCosts,
              label: 'Custos fixos mensais (€)',
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(operationsProvider.notifier)
                    .updateInitialData(
                      ownerName: _optional(ownerName.text),
                      companyTaxId: _optional(taxId.text),
                      companyPhone: _optional(phone.text),
                      companyEmail: _optional(email.text),
                      companyAddress: _optional(address.text),
                      companyPostalCode: _optional(postalCode.text),
                      companyLocality: _optional(locality.text),
                      revenueLastYearCents: centsDeTexto(revenueLastYear.text),
                      revenueThisYearCents: centsDeTexto(revenueThisYear.text),
                      maintenanceLastYearCents: centsDeTexto(
                        maintenanceLastYear.text,
                      ),
                      fixedMonthlyCostsCents: centsDeTexto(
                        fixedMonthlyCosts.text,
                      ),
                    );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.task_alt),
              label: const Text('Guardar dados'),
            ),
          ],
        ),
      ),
    );
  }
}

String _euros(int? cents) =>
    cents == null ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

int? _wholeNumber(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed == null || parsed < 0 ? null : parsed;
}

class HistoricalDataPage extends ConsumerStatefulWidget {
  const HistoricalDataPage({super.key});

  @override
  ConsumerState<HistoricalDataPage> createState() => _HistoricalDataPageState();
}

class _HistoricalDataPageState extends ConsumerState<HistoricalDataPage> {
  late int year;

  @override
  void initState() {
    super.initState();
    year = DateTime.now().year - 1;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final years = List<int>.generate(
      6,
      (index) => DateTime.now().year - 5 + index,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico mensal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Preenche o histórico aos poucos. O Punho só mostra comparações homólogas quando existe um mês real para comparar.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: year,
              decoration: const InputDecoration(labelText: 'Ano'),
              items: [
                for (final item in years)
                  DropdownMenuItem(value: item, child: Text('$item')),
              ],
              onChanged: (value) => setState(() => year = value!),
            ),
            const SizedBox(height: 10),
            const Text(
              'Os valores são recebimentos e despesas efetivamente pagos. Pode usar estimativas redondas se ainda não tiver os extratos.',
            ),
            const SizedBox(height: 12),
            for (var month = 1; month <= 12; month++)
              _HistoricalMonthEditor(
                key: ValueKey('$year-$month'),
                initial: state.historicalMonth(year, month),
                year: year,
                month: month,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalMonthEditor extends ConsumerStatefulWidget {
  const _HistoricalMonthEditor({
    super.key,
    required this.initial,
    required this.year,
    required this.month,
  });
  final HistoricalMonth? initial;
  final int year, month;

  @override
  ConsumerState<_HistoricalMonthEditor> createState() =>
      _HistoricalMonthEditorState();
}

class _HistoricalMonthEditorState
    extends ConsumerState<_HistoricalMonthEditor> {
  late final TextEditingController revenue;
  late final TextEditingController expenses;
  late final TextEditingController advertising;
  late final TextEditingController leads;
  late final TextEditingController converted;
  late final TextEditingController maintenance;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    revenue = TextEditingController(text: _euros(item?.revenueReceivedCents));
    expenses = TextEditingController(text: _euros(item?.paidExpensesCents));
    advertising = TextEditingController(
      text: _euros(item?.advertisingSpendCents),
    );
    leads = TextEditingController(text: item?.leadsReceived?.toString() ?? '');
    converted = TextEditingController(
      text: item?.convertedLeads?.toString() ?? '',
    );
    maintenance = TextEditingController(text: _euros(item?.maintenanceCents));
  }

  @override
  void dispose() {
    for (final controller in [
      revenue,
      expenses,
      advertising,
      leads,
      converted,
      maintenance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.initial?.hasAnyData == true;
    return Card(
      child: ExpansionTile(
        title: Text(monthName(widget.month)),
        subtitle: Text(
          saved ? 'Dados guardados — pode corrigir' : 'Por preencher',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _EuroInput(controller: revenue, label: 'Recebimentos (€)'),
          _EuroInput(controller: expenses, label: 'Despesas pagas (€)'),
          _EuroInput(controller: advertising, label: 'Publicidade (€)'),
          TextField(
            controller: leads,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Leads recebidas'),
          ),
          TextField(
            controller: converted,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Leads convertidas em reserva',
            ),
          ),
          _EuroInput(controller: maintenance, label: 'Manutenção paga (€)'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                ref
                    .read(operationsProvider.notifier)
                    .saveHistoricalMonth(
                      HistoricalMonth(
                        year: widget.year,
                        month: widget.month,
                        revenueReceivedCents: centsDeTexto(revenue.text),
                        paidExpensesCents: centsDeTexto(expenses.text),
                        advertisingSpendCents: centsDeTexto(advertising.text),
                        leadsReceived: _wholeNumber(leads.text),
                        convertedLeads: _wholeNumber(converted.text),
                        maintenanceCents: centsDeTexto(maintenance.text),
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${monthName(widget.month)} guardado.'),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar mês'),
            ),
          ),
        ],
      ),
    );
  }
}

String monthName(int month) => const [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
][month - 1];

class MachinesPage extends ConsumerWidget {
  const MachinesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref
        .watch(operationsProvider)
        .machines
        .where((m) => !m.archived)
        .toList();
    return _PageFrame(
      title: 'Máquinas',
      action: FilledButton.icon(
        onPressed: () => _formularioDeMaquina(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar máquina'),
      ),
      child: ListView(
        children: [
          for (final m in machines)
            Card(
              // Compacto de propósito: em landscape mobile só cabiam três
              // máquinas e meia, e quem tem vinte passava a vida a rolar. A
              // altura da linha era dada pela miniatura de 64 dp e pelo
              // espaçamento por omissão do ListTile — os dois encolheram.
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                minLeadingWidth: 44,
                minVerticalPadding: 4,
                leading: _MachineThumbnail(machine: m),
                // maxLines+ellipsis obrigatórios: sem eles o Flutter parte o
                // texto em coluna vertical de caracteres quando o trailing
                // (chip + 4 botões) rouba a largura toda em ecrãs estreitos.
                title: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  // Só o que existe. Interpolar os dois às cegas deixava um
                  // "Lavadora 8 kg · " com o ponto pendurado no ar sempre que
                  // faltava a referência — e falta em quase todas as máquinas
                  // criadas em lote (visto no Redmi, 04-08-2026).
                  [
                    m.category,
                    m.reference,
                  ].where((valor) => valor.trim().isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // A linha inteira abre a ficha, como na lista de clientes.
                onTap: () => _formularioDeMaquina(context, ref, m),
                // Um só controlo de estado: o chip. Havia três (o chip, um
                // PopupMenuButton com `swap_horiz` que o Cesar leu como "duas
                // setas", e um botão "Disponível" quando estava parada) — todos
                // para o mesmo fim.
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MachineStatusChip(machine: m),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar máquina',
                      onPressed: () => _formularioDeMaquina(context, ref, m),
                    ),
                    if (podeEliminarMaquinas(ref))
                      IconButton(
                        // Caixote e não `archive_outlined`: o Cesar leu o ícone
                        // de arquivo como "mover de sítio" e tocou sem querer.
                        // Por dentro continua a ser soft-delete (`archived`),
                        // mas o utilizador lê "Eliminar" em todo o lado.
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar máquina',
                        onPressed: () =>
                            _confirmarEliminarMaquina(context, ref, m),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A regra, isolada do Riverpod e do `SupabaseConfig` para ser testável: o
/// `enabled` é uma constante de compilação (`--dart-define`) e não se pode
/// mudar num teste.
///
/// Sem Supabase (modo de demonstração) assume-se gestor — senão o único perfil
/// disponível ficava sem acesso a nada.
bool podeEliminar({required bool comSupabase, required bool eGestor}) =>
    !comSupabase || eGestor;

/// Quem pode eliminar máquinas: só o gestor.
bool podeEliminarMaquinas(WidgetRef ref) => podeEliminar(
  comSupabase: SupabaseConfig.enabled,
  eGestor: ref.watch(estadoAcessoProvider).valueOrNull?.eGestor ?? false,
);

/// Confirmação + 6 segundos para anular.
///
/// O botão antigo chamava `archiveMachine` directamente, sem perguntar nada: o
/// Cesar tocou a pensar que movia a máquina de sítio e ela desapareceu.
Future<void> _confirmarEliminarMaquina(
  BuildContext context,
  WidgetRef ref,
  Machine machine,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminar máquina?'),
      content: Text(
        '"${machine.name}" vai desaparecer da lista. Podes reverter durante 6 '
        'segundos depois de confirmares.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return;

  final notifier = ref.read(operationsProvider.notifier);
  // Elimina já — feedback instantâneo — e deixa a porta aberta 6 segundos.
  notifier.archiveMachine(machine.id);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Máquina eliminada.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Anular',
        onPressed: () {
          notifier.unarchiveMachine(machine.id);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Máquina restaurada.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    ),
  );
}

/// Eliminar cliente é soft-delete, como nas máquinas e nos colaboradores:
/// confirmação + 6 segundos para anular. As reservas e recebimentos antigos
/// deste cliente não se perdem — `archiveCustomer` só marca `archived`.
Future<void> _confirmarEliminarCliente(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text('Eliminar ${customer.name}?'),
      content: const Text(
        'A ficha sai da lista. Reservas e recebimentos antigos deste cliente '
        'não se perdem.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return;

  final notifier = ref.read(operationsProvider.notifier);
  notifier.archiveCustomer(customer.id);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text('${customer.name} eliminado.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Anular',
        onPressed: () {
          notifier.unarchiveCustomer(customer.id);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Cliente restaurado.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    ),
  );
}

/// O chip é o **único** controlo de estado: toca-se nele e escolhe-se.
class _MachineStatusChip extends ConsumerWidget {
  const _MachineStatusChip({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = machine.status;
    final color = switch (status) {
      MachineStatus.available => Colors.green.shade700,
      MachineStatus.reserved => Colors.blue.shade700,
      MachineStatus.rented => Colors.deepPurple.shade700,
      MachineStatus.maintenance => Colors.orange.shade800,
      // Dados antigos: lê-se como disponível (ver MachineStatus.stopped).
      MachineStatus.stopped => Colors.green.shade700,
    };
    return PopupMenuButton<MachineStatus>(
      tooltip: 'Mudar estado',
      position: PopupMenuPosition.under,
      onSelected: (escolhido) {
        final changed = ref
            .read(operationsProvider.notifier)
            .updateMachineStatus(machine.id, escolhido);
        if (!changed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A máquina tem uma reserva ativa e não pode ficar disponível.',
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        // Sem "Parada": uma máquina que não está alugada nem em manutenção está
        // disponível, automaticamente.
        for (final opcao in estadosEscolhiveisDeMaquina)
          PopupMenuItem(value: opcao, child: Text(machineStatusLabel(opcao))),
      ],
      child: Chip(
        avatar: Icon(Icons.circle, size: 10, color: color),
        label: Text(machineStatusLabel(status)),
        // A seta diz que se pode tocar; sem ela o chip parece só um rótulo.
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: null,
      ),
    );
  }
}

class _MachineThumbnail extends StatelessWidget {
  const _MachineThumbnail({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final path = machine.photoPaths.isEmpty ? null : machine.photoPaths.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        // 44 e não 64: é a miniatura que manda na altura da linha da lista, e
        // 64 dp só cabia três máquinas e meia num telemóvel deitado.
        width: 44,
        height: 44,
        child: path == null
            ? ColoredBox(
                color: const Color(0xFFFFE5BD),
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : _MachinePhoto(path: path, fit: BoxFit.cover),
      ),
    );
  }
}

class _MachinePhoto extends StatelessWidget {
  const _MachinePhoto({
    required this.path,
    this.width,
    this.height,
    required this.fit,
  });

  final String path;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget unavailable() => const ColoredBox(
      color: Color(0xFFFFE5BD),
      child: Center(child: Icon(Icons.image_not_supported_outlined)),
    );
    if (!MachineImageStore.isRemotePath(path)) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => unavailable(),
      );
    }
    return FutureBuilder<String?>(
      future: MachineImageStore.signedUrl(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return unavailable();
        return Image.network(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => unavailable(),
        );
      },
    );
  }
}

/// Abre o formulário da máquina em ecrã completo.
///
/// Num toque ao lado deitava-se fora o formulário todo; agora não há lado
/// nenhum onde tocar, e sair com texto escrito pergunta primeiro.
Future<void> _formularioDeMaquina(
  BuildContext context,
  WidgetRef ref, [
  Machine? current,
]) => abrirFormulario<void>(
  context,
  (_) => _FormularioDeMaquina(
    notifier: ref.read(operationsProvider.notifier),
    current: current,
  ),
);

/// O formulário é um widget com estado porque é ele quem tem de ser dono dos
/// controladores.
///
/// Antes viviam na função e eram descartados depois do `await showDialog`, que
/// devolve no instante do `Navigator.pop` — a animação de fecho ainda estava a
/// correr e reconstruía os campos com controladores já mortos ("A
/// TextEditingController was used after being disposed"). Com o estado aqui, o
/// `dispose` acontece quando o widget sai de facto da árvore.
class _FormularioDeMaquina extends StatefulWidget {
  const _FormularioDeMaquina({required this.notifier, this.current});

  final OperationsController notifier;
  final Machine? current;

  @override
  State<_FormularioDeMaquina> createState() => _FormularioDeMaquinaState();
}

class _FormularioDeMaquinaState extends State<_FormularioDeMaquina> {
  late final Machine? current = widget.current;
  late final name = TextEditingController(text: current?.name);
  late final reference = TextEditingController(text: current?.reference);
  late final category = TextEditingController(text: current?.category);
  late final dailyRate = TextEditingController(
    text: current?.dailyRateCents == null
        ? ''
        : (current!.dailyRateCents! / 100).toStringAsFixed(2),
  );
  // Os dois campos que faltavam para a célula "Utilização vs Rentabilidade"
  // (`sintese_slide.dart:95-124`) sair de "Por apurar": sem eles há como
  // contar dias alugados, mas não como dizer se isso compensou o que a
  // máquina custou. Opcionais os dois — quem não souber grava a máquina na
  // mesma, e a célula continua "Por apurar", agora com o motivo certo.
  late final purchasePrice = TextEditingController(
    text: current?.purchasePriceCents == null
        ? ''
        : (current!.purchasePriceCents! / 100).toStringAsFixed(2),
  );
  late var acquiredOn = current?.acquiredOn;
  late final notes = TextEditingController(text: current?.notes);
  late final photoPaths = ValueNotifier<List<String>>(
    List<String>.of(current?.photoPaths ?? const []),
  );
  // "Parada" saiu da app na v0.0.5: uma máquina que não está alugada nem em
  // manutenção está disponível. Máquinas antigas gravadas como parada entram
  // aqui já como disponíveis, senão o dropdown apanhava um valor fora da lista.
  late var status = current?.status == MachineStatus.stopped
      ? MachineStatus.available
      : current?.status ?? MachineStatus.available;

  /// Recusa mostrada dentro do formulário, logo por cima do rodapé.
  String? erro;

  @override
  void dispose() {
    name.dispose();
    reference.dispose();
    category.dispose();
    dailyRate.dispose();
    purchasePrice.dispose();
    notes.dispose();
    photoPaths.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identificacao = <Widget>[
      CampoDeTexto(controlador: name, rotulo: 'Nome', autofocus: true),
      CampoDeTexto(controlador: reference, rotulo: 'Número interno ou série'),
      CampoDeTexto(controlador: category, rotulo: 'Categoria'),
      CampoDeTexto(
        controlador: dailyRate,
        rotulo: 'Preço diário de aluguer (€)',
        teclado: const TextInputType.numberWithOptions(decimal: true),
      ),
      CampoDeTexto(
        controlador: purchasePrice,
        rotulo: 'Valor de compra (€) — opcional',
        teclado: const TextInputType.numberWithOptions(decimal: true),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data de aquisição'),
          subtitle: Text(
            acquiredOn == null ? 'Não indicada' : _date(acquiredOn!),
          ),
          trailing: const Icon(Icons.event_outlined),
          onTap: () async {
            final escolhida = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              initialDate: acquiredOn ?? DateTime.now(),
            );
            if (escolhida != null) setState(() => acquiredOn = escolhida);
          },
        ),
      ),
      DropdownButtonFormField<MachineStatus>(
        initialValue: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Estado atual'),
        items: estadosEscolhiveisDeMaquina
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(machineStatusLabel(value)),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => status = v!),
      ),
    ];
    final notasEFotos = <Widget>[
      CampoDeTexto(controlador: notes, rotulo: 'Notas / manutenção', linhas: 3),
      CampoLargo(_FotografiasDaMaquina(photoPaths: photoPaths)),
    ];

    return EcraDeFormulario(
      titulo: current == null ? 'Nova máquina' : 'Editar máquina',
      campos: [...identificacao, ...notasEFotos],
      aviso: erro,
      aoGuardar: () {
        if (name.text.trim().isEmpty) {
          // Antes fechava o diálogo em silêncio e deitava fora o que tinha
          // sido escrito. Depois passou a `SnackBar`, que num telemóvel deitado
          // nasce por baixo do teclado: era o botão a não fazer nada.
          setState(() => erro = 'Indica o nome da máquina.');
          return;
        }
        final anterior = current;
        // A editar usa-se copyWith: construir um Machine novo apagava a data
        // de aquisição e desarquivava máquinas arquivadas.
        final machine = anterior != null
            ? anterior.copyWith(
                name: name.text.trim(),
                reference: reference.text,
                category: category.text,
                status: status,
                dailyRateCents: centsDeTexto(dailyRate.text),
                acquiredOn: acquiredOn,
                purchasePriceCents: centsDeTexto(purchasePrice.text),
                notes: notes.text.trim(),
                photoPaths: photoPaths.value,
              )
            : Machine(
                id: 'm${DateTime.now().microsecondsSinceEpoch}',
                name: name.text.trim(),
                reference: reference.text,
                category: category.text,
                status: status,
                dailyRateCents: centsDeTexto(dailyRate.text),
                acquiredOn: acquiredOn,
                purchasePriceCents: centsDeTexto(purchasePrice.text),
                notes: notes.text.trim(),
                photoPaths: photoPaths.value,
              );
        widget.notifier.saveMachine(machine);
        Navigator.pop(context);
      },
    );
  }
}

/// Tira do corpo do diálogo o bloco das fotografias, que era metade dele.
class _FotografiasDaMaquina extends StatelessWidget {
  const _FotografiasDaMaquina({required this.photoPaths});

  final ValueNotifier<List<String>> photoPaths;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: photoPaths,
      builder: (context, paths, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paths.isEmpty
                ? 'Fotografia principal pendente'
                : 'Fotografias da máquina (${paths.length})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (paths.isNotEmpty)
            SizedBox(
              // 112 dp em vez de 78: à largura de uma coluna do diálogo em
              // paisagem, uma miniatura de 78 não deixa reconhecer a máquina.
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: paths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _MachinePhoto(
                        path: paths[index],
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => photoPaths.value = [
                            for (var i = 0; i < paths.length; i++)
                              if (i != index) paths[i],
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (Platform.isAndroid || Platform.isIOS)
                OutlinedButton.icon(
                  onPressed: () => _acrescentarFotografia(
                    context,
                    photoPaths,
                    MachineImageStore.pickFromCamera,
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tirar foto'),
                ),
              OutlinedButton.icon(
                onPressed: () => _acrescentarFotografia(
                  context,
                  photoPaths,
                  Platform.isAndroid || Platform.isIOS
                      ? MachineImageStore.pickFromGallery
                      : MachineImageStore.pickFromFiles,
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  Platform.isAndroid || Platform.isIOS
                      ? 'Galeria'
                      : 'Escolher imagem',
                ),
              ),
            ],
          ),
          if (paths.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'A primeira fotografia é usada como identificação principal.',
              ),
            ),
        ],
      ),
    );
  }
}

/// Escolhe uma fotografia e junta-a à lista.
///
/// A mensagem de erro estava com os acentos estragados ("NÃ£o foi possÃ­vel") —
/// o ficheiro foi gravado noutra codificação em algum momento. Fica aqui num
/// sítio só para não haver duas cópias a divergir.
Future<void> _acrescentarFotografia(
  BuildContext context,
  ValueNotifier<List<String>> photoPaths,
  Future<String?> Function() escolher,
) async {
  try {
    final path = await escolher();
    if (path != null) photoPaths.value = [...photoPaths.value, path];
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível enviar a fotografia para o arquivo da empresa.',
        ),
      ),
    );
  }
}

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    return _PageFrame(
      title: 'Clientes e leads',
      action: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _formularioDeCliente(context, ref),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Novo cliente'),
          ),
          FilledButton.icon(
            onPressed: () => _formularioDeLead(context, ref),
            icon: const Icon(Icons.add_call),
            label: const Text('Novo lead'),
          ),
        ],
      ),
      child: ListView(
        children: [
          const Text('Clientes', style: TextStyle(fontWeight: FontWeight.w800)),
          // Um cliente arquivado não serve de nada se continuar na lista — é
          // exactamente esse o ponto de o arquivar. Ordem alfabética: sem
          // isto saía pela ordem de chegada da sincronização (achado 20).
          for (final c
              in state.customers.where((c) => !c.archived).toList()..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ))
            Card(
              // Mesmo padrão do cartão de máquina: margem de 3 dp e ListTile
              // compacto, para caber mais linhas em landscape mobile.
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(c.name),
                subtitle: Text(
                  [
                    c.phone,
                    [c.postalCode, c.locality]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' '),
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                // Ecrã de detalhe do cliente: mesmo caminho do de máquina — o
                // NIF, email, morada e notas que o servidor já traz não tinham
                // onde aparecer.
                //
                // A linha inteira abre a ficha. Só o lápis abria, e o lápis é
                // um alvo de 48 dp num canto: quem toca numa lista toca no
                // nome, e ficava com a sensação de que a app não responde
                // (visto no Redmi, 04-08-2026).
                onTap: () => _formularioDeCliente(context, ref, c),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar cliente',
                      onPressed: () => _formularioDeCliente(context, ref, c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar cliente',
                      onPressed: () =>
                          _confirmarEliminarCliente(context, ref, c),
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Leads', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final l in state.leads)
            Card(
              child: ListTile(
                title: Text(l.name),
                // `l.status.name` punha "newLead" e "proposal" à frente do
                // utilizador — nomes de programador num ecrã de gestão.
                subtitle: Text('${l.phone} · ${leadStatusLabel(l.status)}'),
                trailing: l.status == LeadStatus.converted
                    ? null
                    : TextButton(
                        onPressed: () {
                          try {
                            ref
                                .read(operationsProvider.notifier)
                                .convertLead(l);
                          } on StateError catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        },
                        child: const Text('Converter'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Devolve o id do cliente criado ou editado, ou `null` se desistiu.
///
/// Devolver o id é o que permite criar um cliente a meio de uma reserva e
/// continuar de onde se estava, em vez de sair do ecrã e voltar a começar.
///
/// Com [current], abre no modo edição — é o ecrã de detalhe do cliente: o
/// NIF, o email, a morada e as notas que o servidor já traz não tinham onde
/// aparecer, tal como acontecia com as máquinas antes do
/// [_FormularioDeMaquina] ganhar o parâmetro `current`.
/// Abre o formulário do cliente em ecrã completo e devolve o id do que for
/// criado — é por aí que o formulário da marcação recebe o cliente novo.
Future<String?> _formularioDeCliente(
  BuildContext context,
  WidgetRef ref, [
  Customer? current,
]) => abrirFormulario<String>(
  context,
  (_) => _FormularioDeCliente(
    notifier: ref.read(operationsProvider.notifier),
    repository: ref.read(operationRepositoryProvider),
    current: current,
  ),
);

/// Tal como o [_FormularioDeMaquina], é um widget com estado porque é ele quem
/// tem de ser dono dos controladores.
///
/// Enquanto viveram na função e eram descartados a seguir ao `await
/// showDialog`, bastava a lista por baixo reconstruir-se durante a animação de
/// fecho para os campos serem construídos outra vez com controladores já
/// mortos: "A TextEditingController was used after being disposed", e daí o
/// ecrã vermelho. Acontecia ao gravar um cliente cujo telemóvel já existia
/// noutro — é a gravação que mexe na lista de baixo.
class _FormularioDeCliente extends StatefulWidget {
  const _FormularioDeCliente({
    required this.notifier,
    required this.repository,
    this.current,
  });

  final OperationsController notifier;

  /// Só é preciso para gravar uma edição: [OperationsController.addCustomer]
  /// recusa como duplicado um cliente cujo telemóvel ou NIF já exista — e ao
  /// editar, o próprio cliente antes de mudar nada é sempre esse duplicado.
  /// A gravação da edição repete aqui a mesma regra (lendo [customers]
  /// directamente do repositório, porque `notifier.state` não é acessível
  /// fora do próprio `Notifier`), mas excluindo o cliente que está a ser
  /// editado, e grava directamente no repositório.
  final OperationRepository repository;
  final Customer? current;

  @override
  State<_FormularioDeCliente> createState() => _FormularioDeClienteState();
}

class _FormularioDeClienteState extends State<_FormularioDeCliente> {
  late final Customer? current = widget.current;
  late final name = TextEditingController(text: current?.name);
  late final phone = TextEditingController(text: current?.phone);
  late final taxId = TextEditingController(text: current?.taxId);
  late final email = TextEditingController(text: current?.email);
  late final address = TextEditingController(text: current?.address);
  late final postalCode = TextEditingController(text: current?.postalCode);
  late final locality = TextEditingController(text: current?.locality);
  late final notes = TextEditingController(text: current?.notes);

  /// A recusa mostra-se **dentro** do diálogo e não num `SnackBar`.
  ///
  /// Num telemóvel deitado com o teclado aberto, o `SnackBar` nasce por baixo
  /// do teclado: quem tentava gravar um cliente repetido carregava em Guardar e
  /// via o botão não fazer nada.
  String? erro;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    taxId.dispose();
    email.dispose();
    address.dispose();
    postalCode.dispose();
    locality.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EcraDeFormulario(
      titulo: current == null ? 'Novo cliente' : 'Editar cliente',
      campos: [
        CampoDeTexto(
          controlador: name,
          rotulo: 'Nome *',
          autofocus: true,
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(
          controlador: phone,
          rotulo: 'Telemóvel *',
          teclado: TextInputType.phone,
        ),
        CampoDeTexto(
          controlador: taxId,
          rotulo: 'NIF',
          teclado: TextInputType.number,
        ),
        CampoDeTexto(
          controlador: email,
          rotulo: 'Email',
          teclado: TextInputType.emailAddress,
        ),
        CampoDeTexto(
          controlador: address,
          rotulo: 'Morada',
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(controlador: postalCode, rotulo: 'Código-postal'),
        CampoDeTexto(
          controlador: locality,
          rotulo: 'Localidade',
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(controlador: notes, rotulo: 'Notas', linhas: 2),
      ],
      aviso: erro,
      aoGuardar: () {
        if (name.text.trim().isEmpty) {
          setState(() => erro = 'O nome é obrigatório.');
          return;
        }
        // **O contacto também.** Um cliente sem número é um cliente a quem não
        // se liga: não se confirma a entrega, não se avisa da recolha, não se
        // cobra. O nome sozinho serve para a lista e para mais nada — e depois
        // é preciso ir perguntar a alguém quem é que sabe o número.
        if (phone.text.trim().isEmpty) {
          setState(
            () => erro = 'O telemóvel é obrigatório — é por onde se lhe chega.',
          );
          return;
        }
        final anterior = current;
        if (anterior == null) {
          try {
            final novoId = 'c${DateTime.now().microsecondsSinceEpoch}';
            widget.notifier.addCustomer(
              Customer(
                id: novoId,
                name: name.text.trim(),
                phone: phone.text.trim(),
                taxId: taxId.text.trim().isEmpty ? null : taxId.text.trim(),
                email: email.text.trim().isEmpty ? null : email.text.trim(),
                address: address.text.trim().isEmpty
                    ? null
                    : address.text.trim(),
                postalCode: postalCode.text.trim().isEmpty
                    ? null
                    : postalCode.text.trim(),
                locality: locality.text.trim().isEmpty
                    ? null
                    : locality.text.trim(),
                notes: notes.text.trim(),
                createdAt: DateTime.now(),
              ),
            );
            Navigator.pop(context, novoId);
          } on StateError catch (error) {
            setState(() => erro = error.message.toString());
          }
          return;
        }
        // Edição: mesma regra de duplicados do addCustomer, mas excluindo o
        // próprio cliente — sem isto, gravar sem mudar o telemóvel ou o NIF
        // chocava sempre consigo mesmo.
        final telemovel = phone.text.trim();
        final nif = taxId.text.trim();
        final duplicado = widget.repository.customers.any(
          (outro) =>
              outro.id != anterior.id &&
              outro.companyId == anterior.companyId &&
              ((telemovel.isNotEmpty && outro.phone == telemovel) ||
                  (nif.isNotEmpty && outro.taxId == nif)),
        );
        if (duplicado) {
          setState(
            () => erro =
                'Já existe um cliente com o mesmo telemóvel ou NIF na empresa.',
          );
          return;
        }
        widget.repository.saveCustomer(
          Customer(
            id: anterior.id,
            name: name.text.trim(),
            phone: telemovel,
            taxId: nif.isEmpty ? null : nif,
            email: email.text.trim().isEmpty ? null : email.text.trim(),
            address: address.text.trim().isEmpty ? null : address.text.trim(),
            postalCode: postalCode.text.trim().isEmpty
                ? null
                : postalCode.text.trim(),
            locality: locality.text.trim().isEmpty
                ? null
                : locality.text.trim(),
            notes: notes.text.trim(),
            companyId: anterior.companyId,
          ),
        );
        widget.notifier.recarregarDoRepositorio();
        Navigator.pop(context, anterior.id);
      },
    );
  }
}

Future<void> _formularioDeLead(BuildContext context, WidgetRef ref) =>
    abrirFormulario<void>(
      context,
      (_) => _FormularioDeLead(notifier: ref.read(operationsProvider.notifier)),
    );

/// Tal como o [_FormularioDeMaquina] e o [_FormularioDeCliente], é um widget
/// com estado porque é ele quem tem de ser dono dos controladores.
///
/// Antes viviam na função `_leadDialog` e eram descartados logo a seguir ao
/// `await showDialog`, que devolve no instante do `Navigator.pop` — a
/// animação de fecho ainda estava a correr e reconstruía os campos com
/// controladores já mortos ("A TextEditingController was used after being
/// disposed"), daí o ecrã vermelho ao gravar.
class _FormularioDeLead extends StatefulWidget {
  const _FormularioDeLead({required this.notifier});

  final OperationsController notifier;

  @override
  State<_FormularioDeLead> createState() => _FormularioDeLeadState();
}

class _FormularioDeLeadState extends State<_FormularioDeLead> {
  final name = TextEditingController();
  final phone = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EcraDeFormulario(
      titulo: 'Novo lead',
      campos: [
        CampoLargo(
          Text(
            'Regista o contacto agora. Podes completar a oportunidade depois.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        CampoDeTexto(
          controlador: name,
          rotulo: 'Nome',
          autofocus: true,
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(
          controlador: phone,
          rotulo: 'Telemóvel',
          teclado: TextInputType.phone,
        ),
      ],
      aoGuardar: () {
        if (name.text.isNotEmpty && phone.text.isNotEmpty) {
          widget.notifier.addLead(
            Lead(
              id: 'l${DateTime.now().microsecondsSinceEpoch}',
              name: name.text,
              phone: phone.text,
              status: LeadStatus.newLead,
              createdAt: DateTime.now(),
            ),
          );
        }
        Navigator.pop(context);
      },
    );
  }
}

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.responsibleId});
  final String? responsibleId;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

enum _CalendarView { week, month }

class _BookingsPageState extends ConsumerState<BookingsPage> {
  var _view = _CalendarView.week;
  var _focus = DateUtils.dateOnly(DateTime.now());
  String? _selectedMachineId;
  final Set<DateTime> _selectedSlotStarts = {};

  Machine? _selectedMachine(OperationsState state) {
    final matches = state.machines.where(
      (machine) => machine.id == _selectedMachineId && !machine.archived,
    );
    return matches.isEmpty ? null : matches.first;
  }

  // Só a manutenção bloqueia a máquina inteira. "Alugada" e "reservada" são
  // um retrato do que já está marcado, não uma proibição para sempre — a
  // mesma máquina pode voltar a reservar-se para uma data livre, e é o
  // `machineAvailable`/`conflictFor` (por período) quem trava as datas que
  // já têm reserva. Antes disto, uma máquina alugada hoje ficava sem poder
  // receber reservas em nenhuma semana futura, o que inviabilizava o
  // negócio de aluguer.
  bool _machineCanReceiveReservation(Machine machine) =>
      machine.status != MachineStatus.maintenance;

  void _toggleSlot(BuildContext context, DateTime startsAt) {
    setState(() {
      if (!_selectedSlotStarts.add(startsAt)) {
        _selectedSlotStarts.remove(startsAt);
      }
    });
  }

  void _clearSelection() => setState(_selectedSlotStarts.clear);

  /// Quantas vezes se tentou marcar um período sem máquina escolhida.
  ///
  /// É um contador e não um `bool` porque o aviso pisca a cada tentativa: com
  /// um `bool` a segunda tentativa não mudava nada e a animação não repetia.
  int _tentativasSemMaquina = 0;

  /// O intervalo que o calendário está a mostrar: a semana ou o mês do foco.
  DateTimeRange _periodoEmVista() {
    if (_view == _CalendarView.week) {
      final inicio = _weekStart(_focus);
      return DateTimeRange(
        start: inicio,
        end: inicio.add(const Duration(days: 7)),
      );
    }
    return DateTimeRange(
      start: DateTime(_focus.year, _focus.month),
      end: DateTime(_focus.year, _focus.month + 1),
    );
  }

  /// O Semana/Mês, dimensionado para o canto de 86 dp do calendário.
  ///
  /// O `FittedBox` é o que o faz caber: dois rótulos com o tamanho de origem
  /// pedem 116 dp e transbordavam o canto. Encolher a letra é preferível a
  /// abreviar "Semana" — um rótulo cortado obriga a adivinhar.
  Widget _escolhaDeVista() => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      // À esquerda, na mesma coluna do "Manhã" e do "Tarde" que ficam por
      // baixo. Ao centro dos 86 dp desalinhava-se dos dois.
      alignment: Alignment.centerLeft,
      child: ToggleButtons(
        constraints: const BoxConstraints(minHeight: 28, minWidth: 52),
        borderRadius: BorderRadius.circular(8),
        isSelected: [_view == _CalendarView.week, _view == _CalendarView.month],
        onPressed: (index) =>
            setState(() => _view = _CalendarView.values[index]),
        children: const [Text('Semana'), Text('Mês')],
      ),
    ),
  );

  DateTimeRange? get _selectedPeriod {
    if (_selectedSlotStarts.isEmpty ||
        !_isContiguousHalfDaySelection(_selectedSlotStarts)) {
      return null;
    }
    final ordered = _selectedSlotStarts.toList()..sort();
    return DateTimeRange(
      start: ordered.first,
      end: ordered.last.add(const Duration(hours: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final selectedMachine = _selectedMachine(state);
    final period = _selectedPeriod;
    final canAdd =
        selectedMachine != null &&
        _machineCanReceiveReservation(selectedMachine) &&
        period != null;
    // Uma frase só, a que interessa neste momento — ou nenhuma. Antes havia
    // dois SizedBox fixos em volta, que abriam um buraco de 20 dp mesmo quando
    // não havia nada para dizer.
    final (String? aviso, bool avisoForte) = switch (selectedMachine) {
      // "Todas as máquinas" é para ver o parque todo de uma vez. Para marcar é
      // preciso dizer qual sai — uma reserva é sempre de uma máquina concreta.
      null => (
        'A ver todas as máquinas. Escolhe uma para marcar períodos livres.',
        false,
      ),
      final m when !_machineCanReceiveReservation(m) => (
        '${m.reference} está ${machineStatusLabel(m.status).toLowerCase()} e não pode receber reservas.',
        false,
      ),
      _ when _selectedSlotStarts.isNotEmpty && period == null => (
        'Escolhe períodos consecutivos para criar uma única reserva.',
        false,
      ),
      final m when period != null => (
        '${m.reference} · ${_calendarPeriodLabel(period)}',
        true,
      ),
      _ => (null, false),
    };
    return _PageFrame(
      // "Marcações / Reservas" eram duas palavras para a mesma coisa, e a
      // barra lateral já diz "Reservas".
      title: 'Reservas',
      action: LayoutBuilder(
        builder: (_, restricoes) {
          final escolhaDeMaquina = _EscolhaDeMaquina(
            maquinas: state.machines
                .where((machine) => !machine.archived)
                .toList(),
            escolhida: selectedMachine,
            aoEscolher: (machineId) => setState(() {
              _selectedMachineId = machineId;
              _selectedSlotStarts.clear();
              // O aviso cumpriu o que tinha a dizer: volta ao normal.
              _tentativasSemMaquina = 0;
            }),
          );
          final navegacaoDeDatas = _NavegacaoDeDatas(
            focus: _focus,
            view: _view,
            onPrevious: () => setState(
              () => _focus = _view == _CalendarView.week
                  ? _focus.subtract(const Duration(days: 7))
                  : DateTime(_focus.year, _focus.month - 1, 1),
            ),
            onNext: () => setState(
              () => _focus = _view == _CalendarView.week
                  ? _focus.add(const Duration(days: 7))
                  : DateTime(_focus.year, _focus.month + 1, 1),
            ),
          );
          final limparSelecao = _selectedSlotStarts.isEmpty
              ? null
              : TextButton(
                  onPressed: _clearSelection,
                  child: const Text('Limpar seleção'),
                );
          final reservar = FilledButton.icon(
            // Tamanho de origem, como os outros botões da app.
            //
            // Esteve a −5% para a linha caber, quando o Semana/Mês ainda estava
            // aqui e o campo da máquina reservava metade do espaço livre sem o
            // usar. Resolvidas as duas causas, o desconto deixou de ser preciso
            // — e um botão mais pequeno do que os seus pares só se justifica se
            // houver mesmo falta de espaço.
            onPressed: !canAdd
                ? null
                : () async {
                    final saved = await _showCalendarBookingConfirmation(
                      context,
                      ref,
                      machine: selectedMachine,
                      startsAt: period.start,
                      endsAt: period.end,
                      // O que está à vista no calendário é o que define "sem
                      // reserva": quem marca está a olhar para esta semana (ou
                      // para este mês), não para o ano inteiro.
                      periodoEmVista: _periodoEmVista(),
                      rotuloDoPeriodo: _view == _CalendarView.week
                          ? 'esta semana'
                          : 'este mês',
                      responsibleId: widget.responsibleId,
                    );
                    if (mounted && saved) _clearSelection();
                  },
            icon: const Icon(Icons.add),
            // "Reservar" e não "Adicionar reserva": o botão faz uma coisa e o
            // ecrã já se chama Reservas.
            label: Text(
              _selectedSlotStarts.isEmpty
                  ? 'Reservar'
                  : 'Reservar (${_selectedSlotStarts.length})',
            ),
          );

          // Duas linhas quando a largura não dá para uma, e a conta é esta: a
          // máquina pede 220, o "+ Reservar" mede 178, e sobre os 8+8 de ar dá
          // 414. Deitado sobram-lhe 800 e não há discussão; de pé há 363, e é
          // por 51 que não cabia — o `Row` transbordava pela direita.
          //
          // Abaixo de 560 desce a data para a segunda linha. Os 146 que
          // sobrariam dos 414 chegam para as duas setas e pouco mais, e uma
          // data ilegível ao centro não vale a linha que poupa. De pé é a
          // altura que sobra: é dela que se paga.
          if (restricoes.maxWidth < 560) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Aqui `Expanded` e não os 220 fixos: o que sobrar do botão
                    // é dela, e o nome da máquina corta antes de transbordar.
                    Expanded(child: escolhaDeMaquina),
                    const SizedBox(width: 8),
                    reservar,
                  ],
                ),
                const SizedBox(height: 4),
                // O "Limpar seleção" acompanha a data: na linha de cima
                // apareceria e desapareceria a encolher o campo da máquina.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (limparSelecao != null) limparSelecao,
                    navegacaoDeDatas,
                  ],
                ),
              ],
            );
          }

          // Tudo na linha do "+ Reservar", alinhado pelo topo dele.
          //
          // A máquina, a navegação de datas e o Semana/Mês viviam numa segunda
          // barra por baixo, que num telemóvel deitado partia em duas ou três
          // linhas e roubava altura ao calendário — que é o que interessa ver.
          // `Row` e não `Wrap`.
          //
          // O `Wrap` dizia-se numa linha só mas partia assim que não coubesse —
          // e não cabia: o "+ Reservar" caía para uma segunda linha, sozinho, a
          // gastar 50 dp de altura que o calendário precisava. Numa `Row` os
          // campos encolhem em vez de fugirem, e o botão fica onde tem de
          // estar: encostado ao canto superior direito, sempre.
          return Row(
            children: [
              // Largura própria, e não `Flexible`.
              //
              // `Flexible` participa na repartição do espaço livre tal como o
              // `Expanded` da data: com flex igual, o `Row` reservava metade
              // para cada um. O campo da máquina usava só o que o texto pedia e
              // os 85 dp que sobravam da sua quota ficavam mortos — empurrando
              // o botão "+ Reservar" para dentro, longe da margem direita.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: escolhaDeMaquina,
              ),
              const SizedBox(width: 8),
              // A data ao centro do que sobra entre a máquina e o botão. Antes
              // vinha colada à máquina, com todo o vazio a seguir.
              Expanded(child: Center(child: navegacaoDeDatas)),
              // O Semana/Mês desceu para o canto vazio da coluna Manhã/Tarde:
              // não gasta altura nenhuma lá, e aqui era ele que empurrava o
              // botão para a segunda linha.
              const SizedBox(width: 8),
              if (limparSelecao != null) limparSelecao,
              reservar,
            ],
          );
        },
      ),
      child: Column(
        children: [
          if (aviso != null)
            Padding(
              // 5 e 11, e não 8 e 8.
              //
              // O que se vê não é este padding sozinho: por cima soma-se o
              // espaçador de 8 dp do `_PageFrame`, por baixo o Semana/Mês
              // começa 2,3 dp abaixo do topo da linha do calendário. Com 8 dp
              // de cada lado dava 16 em cima contra 10,3 em baixo — o aviso
              // parecia pertencer ao calendário em vez de flutuar entre os
              // dois. Estes números deixam-no a ≈13 dp de cada lado, medidos.
              padding: const EdgeInsets.only(top: 5, bottom: 11),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _AvisoDoCalendario(
                  texto: aviso,
                  forte: avisoForte,
                  tentativas: _tentativasSemMaquina,
                ),
              ),
            ),
          Expanded(
            child: _view == _CalendarView.week
                ? _WeekBookingsCalendar(
                    focus: _focus,
                    bookings: state.bookings,
                    machineId: _selectedMachineId,
                    selectedSlotStarts: _selectedSlotStarts,
                    // Sempre ligado, mesmo sem máquina escolhida.
                    //
                    // Estava `null` nesse caso, e uma célula sem `onTap` não
                    // responde a nada: quem tocasse não recebia sinal nenhum e
                    // ficava a achar que o calendário estava avariado. Agora o
                    // toque chega cá e serve para apontar o que falta fazer.
                    onToggleSlot: (startsAt) {
                      if (selectedMachine == null ||
                          !_machineCanReceiveReservation(selectedMachine)) {
                        setState(() => _tentativasSemMaquina++);
                        return;
                      }
                      _toggleSlot(context, startsAt);
                    },
                    cantoSuperior: _escolhaDeVista(),
                  )
                : _MonthBookingsCalendar(
                    focus: _focus,
                    bookings: state.bookings,
                    machineId: _selectedMachineId,
                    onDaySelected: (day) => setState(() {
                      _focus = day;
                      _view = _CalendarView.week;
                    }),
                    cantoSuperior: _escolhaDeVista(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Barra do calendário: máquina, período e vista, numa linha só.
///
/// A máquina escolhia-se numa fila horizontal de `ChoiceChip` com 64 dp de
/// altura, por baixo desta barra. Com vinte máquinas era uma lista para rolar
/// às cegas, e os 64 dp faltavam ao calendário — que por isso rolava também.
/// Um dropdown de 240 dp diz o mesmo e cabe aqui.
/// A máquina cuja agenda se está a ver.
///
/// Estreita de propósito (190 dp): partilha a linha com a navegação de datas,
/// o Semana/Mês e o "+ Reservar", e a referência da máquina é curta.
class _EscolhaDeMaquina extends StatelessWidget {
  const _EscolhaDeMaquina({
    required this.maquinas,
    required this.escolhida,
    required this.aoEscolher,
  });
  final List<Machine> maquinas;
  final Machine? escolhida;

  /// `null` é **todas as máquinas** — uma escolha, e não a ausência dela.
  final ValueChanged<String?> aoEscolher;

  @override
  Widget build(BuildContext context) {
    if (maquinas.isEmpty) {
      return const Text('Sem máquinas identificadas.');
    }
    return DropdownButton<String>(
      value: escolhida?.id,
      isExpanded: true,
      isDense: true,
      // **"Todas" tem nome.** Sem escolha o calendário já mostrava o parque
      // inteiro, mas o campo dizia só "Máquina" — parecia por preencher, e
      // depois de se escolher uma não havia caminho de volta ao panorama todo.
      // O César, a 10 de Agosto de 2026: «deve existir o "Todas" que retrata no
      // calendário todas as reservas marcadas».
      hint: const Text('Todas as máquinas'),
      // A seta é o único sinal de que aqui se escolhe alguma coisa: sem ela, o
      // nome da máquina lê-se como um rótulo e ninguém lhe toca. Explícita, e
      // não a de origem, para não encolher com o `isDense`.
      icon: const Icon(Icons.keyboard_arrow_down, size: 24),
      // Um ponto acima do corpo de texto: é o campo que comanda o calendário
      // todo, e estava a ler-se como legenda ao lado da data.
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontSize: 15, color: PunhoTheme.navy),
      onChanged: aoEscolher,
      items: [
        const DropdownMenuItem(
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Todas as máquinas')),
            ],
          ),
        ),
        for (final machine in maquinas)
          DropdownMenuItem(
            value: machine.id,
            child: Row(
              children: [
                Icon(
                  machine.status == MachineStatus.available
                      ? Icons.precision_manufacturing_outlined
                      : Icons.build_circle_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // O nome nunca desaparece: uma máquina com referência
                    // ("LAV-11B") ficava só com a referência, sem o nome, e
                    // as placeholders ("Máquina 15", sem referência) ficavam
                    // com o nome — inconsistente e sem forma de reconhecer a
                    // máquina real pelo nome (achado 13).
                    machine.reference.isEmpty
                        ? machine.name
                        : '${machine.name} · ${machine.reference}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Setas e o período que está a ser mostrado.
class _NavegacaoDeDatas extends StatelessWidget {
  const _NavegacaoDeDatas({
    required this.focus,
    required this.view,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime focus;
  final _CalendarView view;
  final VoidCallback onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    final weekStart = _weekStart(focus);
    final fim = weekStart.add(const Duration(days: 6));
    // Sem o ano, e sem o repetir dos dois lados: "27/07/2026 a 02/08/2026" são
    // 23 caracteres para dizer uma semana, e era o que fazia esta linha não
    // caber com o "+ Reservar". O ano está no cabeçalho dos dias e ninguém
    // marca reservas com dois anos de antecedência.
    final label = view == _CalendarView.week
        ? '${_diaEMes(weekStart)} a ${_diaEMes(fim)}'
        : '${monthName(focus.month)} ${focus.year}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Período anterior',
          visualDensity: VisualDensity.compact,
        ),
        // Encolhe em vez de transbordar. Num telemóvel pequeno deitado a linha
        // do topo passava 10 px da margem: a data tem largura própria e, ao
        // centro de um `Expanded`, não tinha como ceder.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Período seguinte',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _WeekBookingsCalendar extends ConsumerWidget {
  const _WeekBookingsCalendar({
    required this.focus,
    required this.bookings,
    required this.machineId,
    required this.selectedSlotStarts,
    required this.onToggleSlot,
    required this.cantoSuperior,
  });
  final DateTime focus;
  final List<Booking> bookings;
  final String? machineId;
  final Set<DateTime> selectedSlotStarts;
  final ValueChanged<DateTime>? onToggleSlot;

  /// O que vai no quadrado vazio à esquerda dos dias — o Semana/Mês.
  final Widget cantoSuperior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = _weekStart(focus);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final state = ref.watch(operationsProvider);
    final machineBookings = machineId == null
        ? const <Booking>[]
        : bookings
              .where((booking) => booking.machineIds.contains(machineId))
              .toList();
    // A semana toda de uma vez: sete colunas e as duas metades do dia dentro do
    // que há. Antes forçava 860 dp de largura mínima e envolvia tudo em dois
    // SingleChildScrollView — a Tarde ficava abaixo da dobra e o gestor não via
    // metade da semana sem rolar em duas direcções. Uma semana são sete dias:
    // ou cabem, ou o ecrã é que é pequeno, e aí encolhem-se as células.
    return Column(
      children: [
        Row(
          children: [
            // O canto por cima dos rótulos Manhã/Tarde estava vazio. É o único
            // sítio do calendário que não custa altura nenhuma a ninguém.
            SizedBox(width: 86, child: cantoSuperior),
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    // Numa linha só: o cabeçalho em duas linhas comia 48 dp de
                    // altura que as células precisavam.
                    '${_weekDay(day)} ${day.day}/${day.month}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
          ],
        ),
        for (final (label, slot) in const [
          ('Manhã', _HalfDay.morning),
          ('Tarde', _HalfDay.afternoon),
        ])
          Expanded(
            child: _WeekSlotRow(
              label: label,
              days: days,
              slot: slot,
              bookings: machineBookings,
              state: state,
              selectedSlotStarts: selectedSlotStarts,
              onToggleSlot: onToggleSlot,
            ),
          ),
      ],
    );
  }
}

class _WeekSlotRow extends ConsumerWidget {
  const _WeekSlotRow({
    required this.label,
    required this.days,
    required this.slot,
    required this.bookings,
    required this.state,
    required this.selectedSlotStarts,
    required this.onToggleSlot,
  });
  final String label;
  final List<DateTime> days;
  final _HalfDay slot;
  final List<Booking> bookings;
  final OperationsState state;
  final Set<DateTime> selectedSlotStarts;
  final ValueChanged<DateTime>? onToggleSlot;

  @override
  // Sem IntrinsicHeight: a linha vive agora dentro de um Expanded, com altura
  // já limitada, e o `stretch` distribui-a. Era preciso quando o calendário
  // estava dentro de um SingleChildScrollView vertical, que lhe dava altura
  // infinita — e o `stretch` fazia disso uma constraint apertada de altura
  // infinita, o que rebentava a montar.
  Widget build(BuildContext context, WidgetRef ref) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 86,
        // Encostado à margem, e não centrado nos 86 dp da coluna.
        //
        // Centrado, "Manhã" nascia a 36,7 dp da aresta do canvas — a margem de
        // 15 mais 21,7 de centragem. Ao lado de tudo o resto da app, que começa
        // a 15, lia-se como se esta coluna estivesse desalinhada. E estava.
        //
        // Mais 10 dp só nestes dois: são rótulos de linha, não um começo de
        // ecrã, e a 15 certos ficavam a competir com o Semana/Mês por cima.
        // O Semana/Mês fica nos 15 — é ele que marca a coluna.
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      for (final day in days)
        Expanded(
          child: _BookingSlotCell(
            day: day,
            slot: slot,
            bookings: bookings
                .where((booking) => _overlapsSlot(booking, day, slot))
                .toList(),
            state: state,
            selected: selectedSlotStarts.contains(_slotStartsAt(day, slot)),
            onToggle: onToggleSlot == null
                ? null
                : () => onToggleSlot!(_slotStartsAt(day, slot)),
          ),
        ),
    ],
  );
}

class _BookingSlotCell extends ConsumerWidget {
  const _BookingSlotCell({
    required this.day,
    required this.slot,
    required this.bookings,
    required this.state,
    required this.selected,
    required this.onToggle,
  });
  final DateTime day;
  final _HalfDay slot;
  final List<Booking> bookings;
  final OperationsState state;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: bookings.isEmpty ? onToggle : null,
    child: Container(
      // Sem minHeight: a célula ocupa o que a linha lhe der. Os 116 dp fixos
      // eram o que obrigava o calendário a rolar.
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: bookings.isEmpty
          ? Center(
              // 24 dp: o alvo de toque é a célula toda, mas o sinal de que se
              // pode marcar aqui tem de se ver de relance.
              child: Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          // Rola por dentro: uma célula com três reservas não transborda para
          // cima da célula de baixo.
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final booking in bookings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => _bookingStatusDialog(context, ref, booking),
                      child: _BookingEventChip(booking: booking, state: state),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _MonthBookingsCalendar extends ConsumerWidget {
  const _MonthBookingsCalendar({
    required this.focus,
    required this.bookings,
    required this.machineId,
    required this.onDaySelected,
    required this.cantoSuperior,
  });
  final DateTime focus;
  final List<Booking> bookings;
  final String? machineId;
  final ValueChanged<DateTime> onDaySelected;

  /// O mesmo canto da vista de semana. Repetido aqui para o Semana/Mês não
  /// mudar de sítio quando se troca de vista — se saltasse, quem clica tinha de
  /// o voltar a procurar.
  final Widget cantoSuperior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = DateTime(focus.year, focus.month);
    final start = _weekStart(first);
    final state = ref.watch(operationsProvider);
    final machineBookings = machineId == null
        ? const <Booking>[]
        : bookings
              .where((booking) => booking.machineIds.contains(machineId))
              .toList();
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 86, child: cantoSuperior),
            for (final day in ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'])
              Expanded(child: Center(child: Text(day))),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          // A grelha alinha com o cabeçalho: os mesmos 86 dp que o canto ocupa
          // em cima têm de sair também daqui, senão os dias ficam a apontar
          // para a coluna errada.
          child: Padding(
            padding: const EdgeInsets.only(left: 86),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final day = start.add(Duration(days: index));
                final dayBookings = machineBookings
                    .where((booking) => _overlapsDay(booking, day))
                    .toList();
                return InkWell(
                  onTap: () => onDaySelected(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: day.month == focus.month
                          ? null
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        for (final booking in dayBookings.take(2))
                          _BookingEventChip(booking: booking, state: state),
                        if (dayBookings.length > 2)
                          Text(
                            '+${dayBookings.length - 2}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingEventChip extends StatelessWidget {
  const _BookingEventChip({required this.booking, required this.state});
  final Booking booking;
  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    final machineNames = booking.machineIds
        .map(
          (id) =>
              state.machines
                  .where((machine) => machine.id == id)
                  .map((machine) => machine.reference)
                  .firstOrNull ??
              'Máquina',
        )
        .join(', ');
    final customer = booking.customerNameSnapshot.isEmpty
        ? state.customers
                  .where((item) => item.id == booking.customerId)
                  .map((item) => item.name)
                  .firstOrNull ??
              'Cliente'
        : booking.customerNameSnapshot;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bookingColor(booking.status).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$machineNames\n$customer',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _bookingColor(booking.status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

DateTime _weekStart(DateTime day) {
  final date = DateUtils.dateOnly(day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _weekDay(DateTime day) =>
    const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][day.weekday - 1];

bool _overlapsDay(Booking booking, DateTime day) {
  final start = DateUtils.dateOnly(day);
  final end = start.add(const Duration(days: 1));
  return booking.startsAt.isBefore(end) && booking.endsAt.isAfter(start);
}

bool _overlapsSlot(Booking booking, DateTime day, _HalfDay slot) {
  final start = _slotStartsAt(day, slot);
  final end = start.add(const Duration(hours: 12));
  return booking.startsAt.isBefore(end) && booking.endsAt.isAfter(start);
}

DateTime _slotStartsAt(DateTime day, _HalfDay slot) =>
    DateTime(day.year, day.month, day.day, slot == _HalfDay.morning ? 0 : 12);

bool _isContiguousHalfDaySelection(Iterable<DateTime> slots) {
  final ordered = slots.toList()..sort();
  if (ordered.isEmpty) return false;
  for (var index = 1; index < ordered.length; index++) {
    if (ordered[index].difference(ordered[index - 1]) !=
        const Duration(hours: 12)) {
      return false;
    }
  }
  return true;
}

String _calendarPeriodLabel(DateTimeRange period) {
  final halfDays = period.duration.inHours ~/ 12;
  final start = period.start;
  final end = period.end;
  final startLabel = '${_date(start)} · ${start.hour == 0 ? 'Manhã' : 'Tarde'}';
  final finalSlotStart = end.subtract(const Duration(hours: 12));
  final endLabel =
      '${_date(finalSlotStart)} · ${finalSlotStart.hour == 0 ? 'Manhã' : 'Tarde'}';
  return halfDays == 1 ? startLabel : '$startLabel até $endLabel';
}

Color _bookingColor(BookingStatus status) => switch (status) {
  BookingStatus.request => Colors.blueGrey,
  BookingStatus.proposalSent => Colors.blue,
  BookingStatus.confirmed => Colors.orange.shade800,
  BookingStatus.rented => Colors.deepPurple,
  BookingStatus.completed => Colors.green.shade700,
  BookingStatus.cancelled => Colors.red.shade700,
};

/// Quem pode mexer no **dinheiro** de uma reserva.
///
/// «O gestor pode alterar, um funcionário não» — Cesar, 9/8/2026. Com Supabase
/// ligado vale o papel real do servidor (`perfil == 'gestor'`), para já estar
/// certo quando houver funcionários com login próprio; sem Supabase, decide o
/// perfil da sessão de demonstração. Mesmo critério do resto da app
/// (`company_settings_page._podeEditar`, `conflitos_providers.ehGestor`).
bool _gestorPodeEditarValor(WidgetRef ref) => SupabaseConfig.enabled
    ? (ref.read(estadoAcessoProvider).valueOrNull?.eGestor ?? false)
    : ref.read(demoSessionProvider).isManager;

String _valorPrevistoLabel(int? cents) =>
    cents == null ? 'Por definir' : '${(cents / 100).toStringAsFixed(2)} €';

Future<void> _bookingStatusDialog(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final podeEditarValor = _gestorPodeEditarValor(ref);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Atualizar estado da reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O valor previsto do trabalho, editável só pelo gestor. Um
          // funcionário vê o número, não lhe toca — o ícone de lápis nem
          // aparece e a linha não responde ao toque.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.euro_outlined),
            title: const Text('Valor previsto'),
            subtitle: Text(_valorPrevistoLabel(booking.expectedValueCents)),
            trailing: podeEditarValor ? const Icon(Icons.edit_outlined) : null,
            enabled: podeEditarValor,
            onTap: podeEditarValor
                ? () async {
                    Navigator.pop(dialogContext);
                    await _editarValorDaReservaDialog(context, ref, booking);
                  }
                : null,
          ),
          const Divider(height: 8),
          for (final status in BookingStatus.values)
            ListTile(
              title: Text(_bookingStatusLabel(status)),
              trailing: status == booking.status
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                final conflict = ref
                    .read(operationsProvider.notifier)
                    .updateBookingStatus(booking.id, status);
                if (conflict != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Conflito: ${conflict.machine.name} está ocupada.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    ),
  );
}

/// Edita o **valor previsto** de uma reserva já criada — o mecanismo que
/// faltava. O controlador já sabia fazê-lo (`definirValorPrevisto`), mas só
/// **A minha semana** o chamava, ao fechar um trabalho; uma reserva com o valor
/// errado não tinha por onde ser corrigida. Só chega aqui quem pode
/// (ver [_gestorPodeEditarValor]); mesmo assim recusa zero ou vazio, como o
/// próprio controlador exige.
Future<void> _editarValorDaReservaDialog(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final controlador = TextEditingController(
    text: booking.expectedValueCents == null
        ? ''
        : (booking.expectedValueCents! / 100).toStringAsFixed(2),
  );
  String? erro;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Valor previsto da reserva'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor (€)',
            helperText: 'O que vai ser facturado ao cliente, IVA incluído.',
            errorText: erro,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final cents = centsDeTexto(controlador.text);
              if (cents == null || cents <= 0) {
                setState(
                  () => erro = controlador.text.trim().isEmpty
                      ? 'Indica um valor superior a zero.'
                      : 'Não consigo ler "${controlador.text.trim()}".',
                );
                return;
              }
              ref
                  .read(operationsProvider.notifier)
                  .definirValorPrevisto(booking.id, cents);
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  controlador.dispose();
}

/// Mudou-se para o modelo, ao lado de `machineStatusLabel` e `leadSourceLabel`,
/// quando **A minha semana** precisou das mesmas seis palavras: duas cópias do
/// vocabulário é como se começa a ter três.
const _bookingStatusLabel = bookingStatusLabel;

/// Valor sentinela do dropdown de cliente: abre o formulário de novo cliente
/// em vez de escolher um existente.
const _novoClienteNaReserva = '__novo_cliente__';

/// A frase que diz o que falta fazer no calendário — e que chama a atenção
/// quando se tenta marcar sem máquina escolhida.
///
/// Tocar numa célula sem máquina não podia continuar a não fazer nada: quem
/// tenta e não recebe resposta conclui que o ecrã está avariado, não que lhe
/// falta um passo. A frase que explica o passo já estava no ecrã — só não
/// estava a ser lida, porque nada a ligava ao gesto.
class _AvisoDoCalendario extends StatefulWidget {
  const _AvisoDoCalendario({
    required this.texto,
    required this.forte,
    required this.tentativas,
  });

  final String texto;
  final bool forte;

  /// Cada incremento é uma tentativa falhada, e dispara nova piscadela.
  final int tentativas;

  @override
  State<_AvisoDoCalendario> createState() => _AvisoDoCalendarioState();
}

class _AvisoDoCalendarioState extends State<_AvisoDoCalendario>
    with SingleTickerProviderStateMixin {
  /// Duas piscadelas. Menos passava despercebido, mais parecia avaria.
  static const _vermelho = Color(0xFFB3261E);

  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  @override
  void didUpdateWidget(covariant _AvisoDoCalendario anterior) {
    super.didUpdateWidget(anterior);
    if (widget.tentativas != anterior.tentativas &&
        widget.tentativas > anterior.tentativas) {
      _controlador.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    // Fica vermelho depois da primeira tentativa, e assim continua até a
    // máquina ser escolhida: a piscadela passa, o problema não.
    final corParada = widget.tentativas > 0 ? _vermelho : base.color;

    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) {
        // Aceso, apagado, aceso, apagado — quatro passos de 25%.
        final fase = (_controlador.value * 4).floor();
        final aPiscar = _controlador.isAnimating && fase.isEven;
        return Text(
          widget.texto,
          style: base.copyWith(
            color: aPiscar ? _vermelho : corParada,
            fontWeight: widget.forte || _controlador.isAnimating
                ? FontWeight.w700
                : base.fontWeight,
          ),
        );
      },
    );
  }
}

/// Se um id ainda existe na lista visível. `null` conta como presente — é o
/// estado "ainda não escolhi", que é legítimo.
bool clientesContem(List<Customer> clientes, String? id) =>
    id == null || clientes.any((cliente) => cliente.id == id);

/// Os clientes que não têm nenhuma reserva dentro de [periodo].
///
/// Quem está a marcar numa semana cheia procura justamente quem ainda lá não
/// está — e a lista completa, nessa altura, é quase toda gente que já tem
/// reserva.
///
/// Sobreposição, e não "começa dentro": uma reserva de segunda a domingo ocupa
/// a quarta-feira mesmo não começando nela. Comparar só o início deixava passar
/// como livre quem está lá a semana toda.
List<Customer> clientesSemReservaNoPeriodo(
  List<Customer> clientes,
  List<Booking> reservas,
  DateTimeRange periodo,
) => clientes
    .where(
      (cliente) => !reservas.any(
        (reserva) =>
            reserva.customerId == cliente.id &&
            reserva.startsAt.isBefore(periodo.end) &&
            reserva.endsAt.isAfter(periodo.start),
      ),
    )
    .toList();

Future<bool> _showCalendarBookingConfirmation(
  BuildContext context,
  WidgetRef ref, {
  required Machine machine,
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTimeRange periodoEmVista,
  required String rotuloDoPeriodo,
  String? responsibleId,
}) async {
  final saved = await abrirFormulario<bool>(
    context,
    (_) => _FormularioDeConfirmacaoDeReserva(
      machine: machine,
      startsAt: startsAt,
      endsAt: endsAt,
      periodoEmVista: periodoEmVista,
      rotuloDoPeriodo: rotuloDoPeriodo,
      responsibleId: responsibleId,
    ),
  );
  return saved ?? false;
}

/// Tal como o [_FormularioDeMaquina] e o [_FormularioDeCliente], é um widget
/// com estado porque é ele quem tem de ser dono dos controladores.
///
/// Antes viviam na função `_showCalendarBookingConfirmation`, junto com
/// `customerId`/`status`/`soSemReserva` num `StatefulBuilder` — os
/// controladores eram descartados logo a seguir ao `await showDialog`, que
/// devolve no instante do `Navigator.pop` enquanto a animação de fecho ainda
/// está a correr, e reconstruíam campos com controladores já mortos ("A
/// TextEditingController was used after being disposed"), daí o ecrã
/// vermelho ao gravar. Aqui é `ConsumerStatefulWidget` — e não só
/// `StatefulWidget` como os outros dois — porque a lista de clientes tem de
/// se manter viva enquanto o diálogo está aberto (`ref.watch`).
class _FormularioDeConfirmacaoDeReserva extends ConsumerStatefulWidget {
  const _FormularioDeConfirmacaoDeReserva({
    required this.machine,
    required this.startsAt,
    required this.endsAt,
    required this.periodoEmVista,
    required this.rotuloDoPeriodo,
    this.responsibleId,
  });

  final Machine machine;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTimeRange periodoEmVista;
  final String rotuloDoPeriodo;
  final String? responsibleId;

  @override
  ConsumerState<_FormularioDeConfirmacaoDeReserva> createState() =>
      _FormularioDeConfirmacaoDeReservaState();
}

class _FormularioDeConfirmacaoDeReservaState
    extends ConsumerState<_FormularioDeConfirmacaoDeReserva> {
  // Sem clientes já não se desiste com um aviso.
  //
  // Era um beco: o Cesar carregava em "+ Reservar", via passar uma faixa de
  // texto e concluía que o campo de cliente não existia. Existia — o diálogo é
  // que nunca chegava a abrir. Agora abre sempre, e cria-se o cliente aqui
  // mesmo, sem sair do calendário nem perder os períodos escolhidos.
  // **Ninguém vem escolhido de fábrica.**
  //
  // Isto abria com o primeiro cliente da lista já no campo, e uma reserva
  // grava-se sem se tocar nele: bastava não reparar para a máquina sair em
  // nome de outra pessoa. O César, a 10 de Agosto de 2026: «o nome do cliente
  // não deve aparecer a preencher o campo por defeito, devia haver uma
  // selecção forçada».
  //
  // Forçada é o que fica: sem escolha não se grava (ver `aoGuardar`), e o campo
  // arranca vazio a pedi-la.
  String? customerId;
  var status = BookingStatus.request;
  // Quem já tem reserva no período em vista fica de fora da lista.
  //
  // Numa semana cheia, a lista de clientes é quase toda gente que já lá está —
  // e quem está a marcar procura justamente quem falta. Arranca desligado: a
  // lista completa é a que nunca esconde ninguém, e o filtro é uma escolha.
  var soSemReserva = false;
  final expectedValue = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    // **O valor chega feito.** A máquina e o período já estão decididos quando
    // este ecrã abre, e o preço/dia foi perguntado no cadastro — não há nada
    // para adivinhar. Fica editável: isto é a tabela, não o preço fechado.
    expectedValue.text = textoDoValorPrevisto(
      [widget.machine],
      widget.startsAt,
      widget.endsAt,
    );
  }

  /// Recusa a mostrar-se dentro do diálogo, como no formulário de cliente —
  /// ver [EcraDeFormulario.aviso]. Nada de gravar um valor inventado
  /// (nem `null` disfarçado de "sem valor") quando o texto escrito não dá
  /// para ler: quem escreveu lixo tem de o ver.
  String? erro;

  @override
  void dispose() {
    expectedValue.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dias = diasDeAluguer(widget.startsAt, widget.endsAt);
    return EcraDeFormulario(
      titulo: 'Confirmar reserva',
      rotuloGuardar: 'Gravar reserva',
      aviso: erro,
      campos: [
        CampoLargo(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.precision_manufacturing_outlined),
            title: Text('${widget.machine.name} · ${widget.machine.reference}'),
            subtitle: Text(
              _calendarPeriodLabel(
                DateTimeRange(start: widget.startsAt, end: widget.endsAt),
              ),
            ),
          ),
        ),
        // Lido do provider a cada reconstrução, e não da fotografia
        // inicial: um cliente criado agora mesmo tem de aparecer já aqui.
        CampoLargo(
          Builder(
            builder: (context) {
              final estado = ref.watch(operationsProvider);
              final todos = estado.customers.where((c) => !c.archived).toList();
              final semReserva = clientesSemReservaNoPeriodo(
                todos,
                estado.bookings,
                widget.periodoEmVista,
              );
              final clientes = soSemReserva ? semReserva : todos;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text('Todos (${todos.length})'),
                      ),
                      ButtonSegment(
                        value: true,
                        // O rótulo diz o período em vista — "esta semana"
                        // ou "este mês" — porque sem isso "sem reserva" não
                        // responde à pergunta "sem reserva quando?".
                        label: Text(
                          'Sem reserva ${widget.rotuloDoPeriodo} '
                          '(${semReserva.length})',
                        ),
                      ),
                    ],
                    selected: {soSemReserva},
                    onSelectionChanged: (escolha) => setState(() {
                      soSemReserva = escolha.first;
                      // O cliente escolhido pode ter acabado de sair da
                      // lista: deixá-lo seleccionado punha o dropdown com
                      // um valor que não está nos itens, e isso rebenta.
                      if (!clientesContem(
                        soSemReserva ? semReserva : todos,
                        customerId,
                      )) {
                        customerId = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: customerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Cliente *',
                      hintText: clientes.isEmpty
                          ? 'Ainda não tens clientes — cria o primeiro'
                          : 'Escolhe para quem é a reserva',
                    ),
                    items: [
                      for (final customer in clientes)
                        DropdownMenuItem(
                          value: customer.id,
                          child: Text(
                            '${customer.name}${customer.phone.isEmpty ? '' : ' · ${customer.phone}'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: _novoClienteNaReserva,
                        child: Row(
                          children: [
                            Icon(Icons.person_add_alt, size: 18),
                            SizedBox(width: 8),
                            Text('Novo cliente…'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      if (value != _novoClienteNaReserva) {
                        setState(() => customerId = value);
                        return;
                      }
                      final novo = await _formularioDeCliente(context, ref);
                      if (novo != null) {
                        setState(() => customerId = novo);
                      } else {
                        // Desistiu de criar: repõe o que estava, senão o campo
                        // ficava preso em "Novo cliente…".
                        setState(() {});
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
        DropdownButtonFormField<BookingStatus>(
          isExpanded: true,
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Estado inicial'),
          items: const [
            DropdownMenuItem(
              value: BookingStatus.request,
              child: Text('Pedido'),
            ),
            DropdownMenuItem(
              value: BookingStatus.proposalSent,
              child: Text('Proposta enviada'),
            ),
            DropdownMenuItem(
              value: BookingStatus.confirmed,
              child: Text('Confirmada'),
            ),
          ],
          onChanged: (value) => setState(() => status = value!),
        ),
        CampoDeTexto(
          controlador: expectedValue,
          rotulo: 'Valor previsto (€)',
          ajuda: _ajudaDoValorPrevisto([widget.machine], dias),
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
        CampoDeTexto(controlador: notes, rotulo: 'Notas', linhas: 2),
      ],
      aoGuardar: () {
        // Sem cliente não há reserva.
        if (customerId == null) {
          setState(() => erro = 'Escolhe um cliente para confirmar a reserva.');
          return;
        }
        final textoValor = expectedValue.text.trim();
        final cents = centsDeTexto(expectedValue.text);
        // Vazio é legítimo — nem toda a reserva tem valor previsto à
        // cabeça. Texto que não se consegue ler é sempre erro: gravar em
        // silêncio inventava um valor de zero.
        if (textoValor.isNotEmpty && cents == null) {
          setState(
            () => erro =
                'Valor previsto: não percebi "$textoValor" — escreve, por '
                'exemplo, 1.500,00.',
          );
          return;
        }
        final conflict = ref
            .read(operationsProvider.notifier)
            .addBooking(
              Booking(
                id: 'b${DateTime.now().microsecondsSinceEpoch}',
                customerId: customerId!,
                machineIds: [widget.machine.id],
                startsAt: widget.startsAt,
                endsAt: widget.endsAt,
                status: status,
                expectedValueCents: cents,
                collaboratorResponsibleId: widget.responsibleId,
                notes: notes.text.trim(),
              ),
            );
        if (conflict != null) {
          setState(
            () => erro = 'Conflito: ${conflict.machine.name} já está ocupada.',
          );
          return;
        }
        Navigator.pop(context, true);
      },
    );
  }
}

/// Abre a marcação operacional usada também pela área do colaborador.
///
/// As opções de agenda (data e período) ficam privadas a este ecrã, para não
/// expor tipos internos como parte da API partilhada com os restantes fluxos.
Future<void> showBookingForm(
  BuildContext context,
  WidgetRef ref, {
  String? responsibleId,
}) => _showBookingForm(context, ref, responsibleId: responsibleId);

Future<void> _showBookingForm(
  BuildContext context,
  WidgetRef ref, {
  String? responsibleId,
  DateTime? initialDate,
  _BookingDuration? initialDuration,
  _HalfDay? initialHalfDay,
}) async {
  final state = ref.read(operationsProvider);
  if (state.customers.where((c) => !c.archived).isEmpty ||
      state.machines.where((m) => !m.archived).isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Regista primeiro pelo menos um cliente e uma máquina.'),
      ),
    );
    return;
  }
  await abrirFormulario<void>(
    context,
    (_) => _FormularioDeMarcacao(
      responsibleId: responsibleId,
      initialDate: initialDate,
      initialDuration: initialDuration,
      initialHalfDay: initialHalfDay,
    ),
  );
}

/// Tal como os outros formulários deste ficheiro, é um widget com estado
/// porque é ele quem tem de ser dono dos controladores.
///
/// Antes vivia na função `_showBookingForm`, com `customerId`/`machineId`/
/// `status`/as datas/`collaboratorId` capturados por um `StatefulBuilder` —
/// os controladores `expectedValue`/`notes` eram descartados logo a seguir ao
/// `await showDialog`, que devolve enquanto a animação de fecho ainda está a
/// correr, e por vezes reconstruíam campos já mortos ("A TextEditingController
/// was used after being disposed"), daí o ecrã vermelho ao gravar.
class _FormularioDeMarcacao extends ConsumerStatefulWidget {
  const _FormularioDeMarcacao({
    this.responsibleId,
    this.initialDate,
    this.initialDuration,
    this.initialHalfDay,
  });

  final String? responsibleId;
  final DateTime? initialDate;
  final _BookingDuration? initialDuration;
  final _HalfDay? initialHalfDay;

  @override
  ConsumerState<_FormularioDeMarcacao> createState() =>
      _FormularioDeMarcacaoState();
}

class _FormularioDeMarcacaoState extends ConsumerState<_FormularioDeMarcacao> {
  // Fotografia do estado no instante em que o diálogo abriu, tal como
  // acontecia antes com o `state` capturado uma vez pela função que abria o
  // `showDialog`: um cliente ou máquina criados enquanto o diálogo está
  // aberto só aparecem da próxima vez que se abrir.
  late final state = ref.read(operationsProvider);
  // Um cliente arquivado não é uma opção válida para uma marcação nova — só
  // continua a existir para as reservas antigas continuarem a apontar para
  // alguém.
  late final activeCustomers = state.customers
      .where((c) => !c.archived)
      .toList();
  // Ninguém vem escolhido de fábrica — a mesma regra do outro formulário de
  // reserva. `activeCustomers.first` punha aqui o primeiro cliente da lista e
  // uma marcação gravava-se sem se tocar no campo: bastava não reparar para a
  // máquina sair em nome de outra pessoa.
  String? customerId;
  late var machineId = state.machines.firstWhere((m) => !m.archived).id;
  var status = BookingStatus.request;

  /// O valor previsto deixa de se recalcular assim que alguém lhe mexe.
  ///
  /// Enquanto ninguém lhe toca, o campo segue a tabela: trocar de máquina ou
  /// alargar os dias muda o número à frente de quem está a marcar. Depois de
  /// escrito à mão, o que lá está é a decisão de quem vende, e nenhuma mudança
  /// de máquina a apaga.
  var valorEscritoAMao = false;
  late var startDate = DateUtils.dateOnly(
    widget.initialDate ?? DateTime.now().add(const Duration(days: 1)),
  );
  late var endDate = startDate;
  late var duration = widget.initialDuration ?? _BookingDuration.halfDay;
  late var halfDay = widget.initialHalfDay ?? _HalfDay.morning;
  late String? collaboratorId = widget.responsibleId;
  final expectedValue = TextEditingController();
  final notes = TextEditingController();

  /// Recusa a mostrar-se dentro do formulário — ver [EcraDeFormulario.aviso].
  String? erro;

  @override
  void dispose() {
    expectedValue.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startsAt = _bookingStartsAt(startDate, duration, halfDay);
    final endsAt = _bookingEndsAt(endDate, duration, halfDay);
    final dias = diasDeAluguer(startsAt, endsAt);
    final availableMachines = state.machines
        .where(
          (machine) =>
              !machine.archived &&
              ref
                  .read(operationsProvider.notifier)
                  .machineAvailable(machine.id, startsAt, endsAt),
        )
        .toList();
    if (!availableMachines.any((machine) => machine.id == machineId)) {
      machineId = availableMachines.isNotEmpty
          ? availableMachines.first.id
          : state.machines.firstWhere((machine) => !machine.archived).id;
    }
    final maquinaEscolhida = state.machines.firstWhere(
      (machine) => machine.id == machineId,
    );
    // Segue a tabela enquanto ninguém escrever por cima. Escrito directamente
    // no controlador, e não com `setState`: estamos dentro do `build`.
    if (!valorEscritoAMao) {
      expectedValue.text = textoDoValorPrevisto(
        [maquinaEscolhida],
        startsAt,
        endsAt,
      );
    }
    return EcraDeFormulario(
      titulo: 'Nova marcação / reserva',
      rotuloGuardar: 'Guardar marcação',
      aviso: erro,
      campos: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: customerId,
          decoration: const InputDecoration(
            labelText: 'Cliente *',
            hintText: 'Escolhe para quem é a marcação',
          ),
          items: activeCustomers
              .map(
                (customer) => DropdownMenuItem(
                  value: customer.id,
                  child: Text(customer.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => customerId = value!),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: machineId,
          decoration: const InputDecoration(labelText: 'Máquina'),
          items:
              (availableMachines.isEmpty
                      ? state.machines
                            .where((machine) => !machine.archived)
                            .toList()
                      : availableMachines)
                  .map(
                    (machine) => DropdownMenuItem(
                      value: machine.id,
                      child: Text('${machine.name} · ${machine.reference}'),
                    ),
                  )
                  .toList(),
          onChanged: availableMachines.isEmpty
              ? null
              : (value) => setState(() => machineId = value!),
        ),
        DropdownButtonFormField<_BookingDuration>(
          isExpanded: true,
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Duração'),
          items: const [
            DropdownMenuItem(
              value: _BookingDuration.halfDay,
              child: Text('Meio dia'),
            ),
            DropdownMenuItem(
              value: _BookingDuration.fullDay,
              child: Text('Dia inteiro'),
            ),
            DropdownMenuItem(
              value: _BookingDuration.multipleDays,
              child: Text('Vários dias seguidos'),
            ),
          ],
          onChanged: (value) => setState(() {
            duration = value!;
            if (duration != _BookingDuration.multipleDays) {
              endDate = startDate;
            }
          }),
        ),
        if (duration == _BookingDuration.halfDay)
          DropdownButtonFormField<_HalfDay>(
            isExpanded: true,
            initialValue: halfDay,
            decoration: const InputDecoration(labelText: 'Período'),
            items: const [
              DropdownMenuItem(value: _HalfDay.morning, child: Text('Manhã')),
              DropdownMenuItem(value: _HalfDay.afternoon, child: Text('Tarde')),
            ],
            onChanged: (value) => setState(() => halfDay = value!),
          ),
        CampoLargo(
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Período'),
            subtitle: Text(
              _bookingDatesLabel(startDate, endDate, duration, halfDay),
            ),
            trailing: const Icon(Icons.date_range_outlined),
            onTap: () async {
              if (duration == _BookingDuration.multipleDays) {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDateRange: DateTimeRange(
                    start: startDate,
                    end: endDate,
                  ),
                );
                if (range == null) return;
                setState(() {
                  startDate = DateUtils.dateOnly(range.start);
                  endDate = DateUtils.dateOnly(range.end);
                });
                return;
              }
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate: startDate,
              );
              if (date == null) return;
              setState(() {
                startDate = DateUtils.dateOnly(date);
                endDate = startDate;
              });
            },
          ),
        ),
        DropdownButtonFormField<BookingStatus>(
          isExpanded: true,
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Estado inicial'),
          items: const [
            DropdownMenuItem(
              value: BookingStatus.request,
              child: Text('Pedido'),
            ),
            DropdownMenuItem(
              value: BookingStatus.proposalSent,
              child: Text('Proposta enviada'),
            ),
            DropdownMenuItem(
              value: BookingStatus.confirmed,
              child: Text('Confirmada'),
            ),
          ],
          onChanged: (value) => setState(() => status = value!),
        ),
        if (widget.responsibleId == null)
          DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: collaboratorId,
            decoration: const InputDecoration(labelText: 'Responsável'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Gestor'),
              ),
              ...state.collaborators
                  .where((collaborator) => !collaborator.archived)
                  .map(
                    (collaborator) => DropdownMenuItem<String?>(
                      value: collaborator.id,
                      child: Text(collaborator.name),
                    ),
                  ),
            ],
            onChanged: (value) => setState(() => collaboratorId = value),
          )
        else
          CampoLargo(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Registada por'),
              subtitle: Text(
                state.collaborators
                        .where(
                          (collaborator) =>
                              collaborator.id == widget.responsibleId,
                        )
                        .map((collaborator) => collaborator.name)
                        .firstOrNull ??
                    'Colaborador',
              ),
            ),
          ),
        CampoDeTexto(
          controlador: expectedValue,
          rotulo: 'Valor previsto (€)',
          ajuda: valorEscritoAMao
              ? 'Escrito à mão — já não segue a tabela'
              : _ajudaDoValorPrevisto([maquinaEscolhida], dias),
          teclado: const TextInputType.numberWithOptions(decimal: true),
          aoMudar: (_) {
            if (!valorEscritoAMao) setState(() => valorEscritoAMao = true);
          },
        ),
        CampoDeTexto(controlador: notes, rotulo: 'Notas', linhas: 2),
        if (availableMachines.isEmpty)
          const CampoLargo(Text('Não há máquinas disponíveis neste período.')),
      ],
      aoGuardar: () {
        if (availableMachines.isEmpty) {
          setState(() => erro = 'Não há máquinas disponíveis neste período.');
          return;
        }
        // Sem cliente não há marcação.
        if (customerId == null) {
          setState(() => erro = 'Escolhe um cliente para guardar a marcação.');
          return;
        }
        final textoValor = expectedValue.text.trim();
        final cents = centsDeTexto(expectedValue.text);
        // Vazio é legítimo — nem toda a marcação tem valor previsto à
        // cabeça. Texto que não se consegue ler é sempre erro: gravar em
        // silêncio inventava um valor de zero.
        if (textoValor.isNotEmpty && cents == null) {
          setState(
            () => erro =
                'Valor previsto: não percebi "$textoValor" — escreve, por '
                'exemplo, 1.500,00.',
          );
          return;
        }
        // addBooking valida duração mínima, máquinas por identificar e
        // máquinas paradas com ArgumentError. Sem este try a excepção subia
        // por tratar e rebentava o ecrã.
        final BookingConflict? conflict;
        try {
          conflict = ref
              .read(operationsProvider.notifier)
              .addBooking(
                Booking(
                  id: 'b${DateTime.now().microsecondsSinceEpoch}',
                  customerId: customerId!,
                  machineIds: [machineId],
                  startsAt: startsAt,
                  endsAt: endsAt,
                  status: status,
                  expectedValueCents: cents,
                  collaboratorResponsibleId: collaboratorId,
                  notes: notes.text.trim(),
                ),
              );
        } on ArgumentError catch (error) {
          setState(() => erro = '${error.message}');
          return;
        }
        if (conflict != null) {
          final maquinaEmConflito = conflict.machine.name;
          setState(
            () => erro = 'Conflito: $maquinaEmConflito já está ocupada.',
          );
          return;
        }
        Navigator.pop(context);
      },
    );
  }
}

/// A linha por baixo do "Valor previsto": de onde saiu o número que lá está.
///
/// Um campo que se preenche sozinho e não diz porquê é pior do que um campo
/// vazio — quem o lê não sabe se pode confiar nele nem o que muda se lhe mexer.
/// Aqui diz-se a conta: preço/dia × dias. E quando não há tabela diz-se isso,
/// em vez de deixar o campo em branco sem explicação.
String _ajudaDoValorPrevisto(List<Machine> maquinas, double dias) {
  final semPreco = maquinas.where(
    (m) => m.dailyRateCents == null || m.dailyRateCents! <= 0,
  );
  if (semPreco.isNotEmpty) {
    return semPreco.length == maquinas.length && maquinas.length == 1
        ? '${maquinas.single.name} não tem preço/dia — escreve o valor combinado'
        : 'Sem preço/dia em ${semPreco.map((m) => m.name).join(', ')} — '
              'escreve o valor combinado';
  }
  final tabela = maquinas
      .map((m) => '${textoDeCents(m.dailyRateCents!)} €/dia')
      .join(' + ');
  return '$tabela × ${_diasEmTexto(dias)}. Editável.';
}

/// "meio dia", "1 dia", "3 dias", "1,5 dias".
String _diasEmTexto(double dias) {
  if (dias == 0.5) return 'meio dia';
  if (dias == 1) return '1 dia';
  final redondo = dias == dias.roundToDouble();
  final numero = redondo
      ? dias.round().toString()
      : dias.toStringAsFixed(1).replaceAll('.', ',');
  return '$numero dias';
}

enum _BookingDuration { halfDay, fullDay, multipleDays }

enum _HalfDay { morning, afternoon }

DateTime _bookingStartsAt(
  DateTime day,
  _BookingDuration duration,
  _HalfDay halfDay,
) => switch (duration) {
  _BookingDuration.halfDay when halfDay == _HalfDay.afternoon => DateTime(
    day.year,
    day.month,
    day.day,
    12,
  ),
  _ => DateTime(day.year, day.month, day.day),
};

DateTime _bookingEndsAt(
  DateTime endDay,
  _BookingDuration duration,
  _HalfDay halfDay,
) => switch (duration) {
  _BookingDuration.halfDay when halfDay == _HalfDay.morning => DateTime(
    endDay.year,
    endDay.month,
    endDay.day,
    12,
  ),
  _ => DateTime(endDay.year, endDay.month, endDay.day + 1),
};

String _bookingDatesLabel(
  DateTime start,
  DateTime end,
  _BookingDuration duration,
  _HalfDay halfDay,
) {
  final dates = duration == _BookingDuration.multipleDays
      ? '${_date(start)} a ${_date(end)}'
      : _date(start);
  final detail = switch (duration) {
    _BookingDuration.halfDay => halfDay == _HalfDay.morning ? 'Manhã' : 'Tarde',
    _BookingDuration.fullDay => 'Dia inteiro',
    _BookingDuration.multipleDays => 'Dias seguidos',
  };
  return '$dates · $detail';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

/// Dia e mês, sem o ano. Para a barra do calendário, onde o ano não acrescenta
/// nada e o espaço é o que decide se tudo cabe numa linha.
String _diaEMes(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

// ignore: unused_element
Future<void> _bookingDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(operationsProvider);
  final start = DateTime.now().add(const Duration(days: 1));
  final end = start.add(const Duration(days: 1));
  final available = state.machines
      .where(
        (m) => ref
            .read(operationsProvider.notifier)
            .machineAvailable(m.id, start, end),
      )
      .toList();
  if (state.customers.isEmpty || available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('É necessário um cliente e uma máquina disponível.'),
      ),
    );
    return;
  }
  final selected = available.first;
  final conflict = ref
      .read(operationsProvider.notifier)
      .addBooking(
        Booking(
          id: 'b${DateTime.now().microsecondsSinceEpoch}',
          customerId: state.customers.first.id,
          machineIds: [selected.id],
          startsAt: start,
          endsAt: end,
          status: BookingStatus.confirmed,
        ),
      );
  if (conflict != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conflito: ${conflict.machine.name} está ocupada.'),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.action,
    required this.child,
  });
  // Mantido no construtor para não partir os call sites, mas o header foi
  // removido: era só rótulo informativo (o item da sidebar já mostra em que
  // ecrã se está, com border laranja à esquerda) e ocupava ~60 dp de altura
  // que agora entram no conteúdo — sobretudo útil em landscape mobile.
  final String title;
  final Widget action, child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      // Estes ecrãs começam por um botão de acção, daí a margem de topo mais
      // curta. Os números vivem todos em [MargensDoCanvas].
      padding: const EdgeInsets.fromLTRB(
        MargensDoCanvas.lateral,
        MargensDoCanvas.verticalComBotaoNoTopo,
        MargensDoCanvas.lateral,
        MargensDoCanvas.vertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Só o action (botão de acção principal do ecrã), alinhado à direita.
          Align(alignment: Alignment.centerRight, child: action),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
