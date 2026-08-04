import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/empresa_sync/ficha_recebida_provider.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/session/demo_session.dart';
import '../../../core/theme/punho_theme.dart';
import '../../../shared/widgets/brand_lockup.dart';
import '../../../shared/widgets/versao_app.dart';
import '../../ciclo/presentation/minha_semana_page.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../conta/presentation/perfil_popup.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../empresa/presentation/empresa_page.dart';
import '../../licenca/presentation/licenca_banner.dart';
import '../../operations/presentation/operational_pages.dart';
import '../../tarefas/data/tarefas_service.dart';
import '../../tarefas/presentation/tarefas_page.dart';
import '../../workforce/presentation/workforce_pages.dart';

/// Chave da barra lateral. Existe porque os rótulos dos destinos ("Máquinas")
/// repetem-se nos nomes dos slides do painel: sem ela os testes não sabiam
/// distinguir o rótulo da barra do nome do slide.
const chaveDaBarraLateral = Key('barra-lateral');

/// O avatar do fundo da barra lateral, que abre o Perfil. Tem chave própria
/// porque há outros ícones de pessoa no ecrã e os testes precisam deste.
const chaveDoAvatarDoPerfil = Key('avatar-do-perfil');

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Altura da faixa escura por trás dos glifos da barra de estado.
///
/// Medido no Redmi Note 10 Pro deitado: a barra do sistema tem 33,8 dp e os
/// glifos — relógio, rede, bateria — vivem entre os 9,5 e os 21,8. Sobravam
/// 12 dp de barra sem nada por baixo deles.
///
/// A altura da barra é do sistema e não se encolhe. O que se pode fazer é a app
/// desenhar por baixo dela e parar a faixa pouco depois de os glifos pararem.
///
/// Esteve em 22 dp — o fim dos glifos com uma fracção de folga. Colava-lhes por
/// baixo: os 9,5 dp de ar que têm em cima não tinham nada do outro lado, e a
/// barra ficava a apertá-los contra a aresta. 27 dp devolvem-lhes 5,2 dp por
/// baixo, cerca de metade da folga de cima — o suficiente para respirarem sem
/// gastar a barra toda. Sobram 6,8 dp que passam para o conteúdo.
///
/// Nunca passa da margem que o sistema reporta: num ecrã sem barra a moldura não
/// existe, e num ecrã com barra mais baixa a faixa acompanha-a em vez de inventar
/// altura que ninguém pediu.
const _alturaDaFaixa = 27.0;

class _AppShellState extends ConsumerState<AppShell> {
  bool? _porBaixoDasBarras;

  @override
  void initState() {
    super.initState();
    // O único ecrã da app que leva landscape (Decisão 13). Aqui e em mais
    // nenhum: o painel são cinco slides de quatro KPIs lado a lado, e em
    // portrait não caberia sem espremer os números até não se lerem.
    OrientacaoDoContexto.landscapeJa();
  }

  @override
  void dispose() {
    // A app não é toda landscape nem toda edge-to-edge: os outros ecrãs contam
    // com a janela já inserida pelo sistema.
    _janela(porBaixoDasBarras: false);
    super.dispose();
  }

  /// Desenhar por baixo das barras do sistema — ou deixar o Android inserir a
  /// janela, como faz por omissão.
  ///
  /// Sem edge-to-edge a moldura deste ficheiro nunca chega a ser construída:
  /// `MediaQuery.padding` vem a zeros e o navy do topo passa a ser só o
  /// `statusBarColor`. Mas só a moldura sabe viver assim — é ela que pinta a
  /// faixa por trás dos glifos e que afasta o conteúdo do recorte da câmara.
  ///
  /// Esteve no `initState`, e apanhava também o que este `build` devolve antes
  /// de lá chegar: o onboarding ficava com o cabeçalho por baixo do relógio e o
  /// formulário rebentava 59 dp por baixo do teclado. O modo passou a
  /// acompanhar o ramo que está no ecrã.
  void _janela({required bool porBaixoDasBarras}) {
    if (_porBaixoDasBarras == porBaixoDasBarras) return;
    _porBaixoDasBarras = porBaixoDasBarras;
    SystemChrome.setEnabledSystemUIMode(
      porBaixoDasBarras ? SystemUiMode.edgeToEdge : SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    final operational = ref.watch(operationsProvider);
    final session = ref.watch(demoSessionProvider);
    if (!operational.onboarded) {
      _janela(porBaixoDasBarras: false);
      // Antes de perguntar tudo, ver se a empresa já existe no servidor: quem
      // trocou de telemóvel ou reinstalou tem a ficha lá, e não tem de a
      // escrever outra vez. Enquanto não se sabe, o onboarding fica à espera —
      // são milissegundos, e piscar o primeiro passo para o substituir era
      // pior do que não o mostrar já.
      final ficha = ref.watch(fichaRecebidaProvider);
      if (ficha.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const OnboardingPage();
    }
    // Só o modo de demonstração local decide o perfil por aqui. Com Supabase
    // ligado quem escolhe a shell é o AcessoGate, a partir do perfil aprovado
    // em punho_membros — a esta altura já se sabe que é gestor.
    if (!SupabaseConfig.enabled && !session.isManager) {
      _janela(porBaixoDasBarras: false);
      return const CollaboratorShell();
    }

    final destination = ref.watch(navigationProvider);
    final destinations = visibleOperationalDestinations(operational);
    final isDesktop = MediaQuery.sizeOf(context).width >= 680;
    // Só o ramo largo tem moldura. No estreito não há faixa nem barra lateral
    // para absorver o que o edge-to-edge descobre, e o conteúdo ficaria por
    // baixo das barras sem nada a protegê-lo.
    _janela(porBaixoDasBarras: isDesktop);
    // O aviso de licença fica acima do conteúdo para aparecer em todos os
    // ecrãs, e não só no painel de gestão. Encolhe a zero quando está tudo bem.
    final content = Column(
      children: [
        const LicencaBanner(),
        Expanded(
          // A moldura da shell já gastou as margens do sistema: a faixa gastou
          // o topo, a barra lateral gastou a esquerda, e o canvas afasta-se da
          // direita logo aqui abaixo. O que sobra é área limpa — e é preciso
          // dizê-lo, senão o `SafeArea` de cada página desconta tudo outra vez.
          //
          // Era isso que empurrava o painel para a esquerda: os 47,3 dp da
          // barra de navegação saíam duas vezes, e os cartões acabavam a 47 dp
          // do fim do canvas, com uma tira branca à direita a não fazer nada.
          //
          // Só no ramo largo. No estreito não há moldura nenhuma a absorver as
          // margens, e cada página continua a precisar de as respeitar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: isDesktop,
            removeLeft: isDesktop,
            removeRight: isDesktop,
            child: _DestinationContent(destination: destination),
          ),
        ),
      ],
    );

    // Sem widget de bloqueio à volta: a orientação é decidida no `initState`,
    // uma vez, em vez de ser reaplicada a cada rebuild do layout.
    if (isDesktop) {
      // Em Android landscape, a área das notificações pode desenhar-se por
      // cima do Scaffold. A faixa é deliberadamente parte do layout (e não
      // apenas `statusBarColor`), para nunca deixar ícones claros sobre o
      // fundo claro do painel.
      final topInset = MediaQuery.paddingOf(context).top;
      // A faixa acompanha a área das notificações e nada mais.
      //
      // É ela que põe as notificações em fundo escuro — em Android recente o
      // `statusBarColor` já não é respeitado, e sem faixa ficavam ícones claros
      // sobre o branco do conteúdo.
      //
      // A faixa acompanha os glifos e pára onde eles param. O vazio que a barra
      // de estado deixa por baixo do relógio passa a ser conteúdo.
      //
      // Esteve em `topInset - 6` com tecto de 20, para aparar o que se julgava
      // ser o recorte da câmara a inflacionar a margem. Isso estava errado por
      // duas razões: neste telemóvel o furo fica ao centro do topo **em pé**,
      // portanto em landscape aparece de lado e a margem superior é só a barra
      // de estado; e o tecto de 20 era um número inventado. Agora a altura é
      // uma medida — ver [_alturaDaFaixa].
      final alturaDaMoldura = topInset < _alturaDaFaixa
          ? topInset
          : _alturaDaFaixa;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          // Transparente, e não navy: em edge-to-edge o `statusBarColor` pintava
          // a barra toda e engolia de volta os 12 dp que se foram buscar. Quem
          // põe fundo escuro por trás dos glifos é a faixa aqui abaixo.
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: Column(
            children: [
              if (alturaDaMoldura > 0)
                SizedBox(
                  height: alturaDaMoldura,
                  // A largura tem de ser dita. Sem ela, o `Column` centra com
                  // restrições soltas e o `ColoredBox` — que não tem filho para
                  // lhe dar tamanho — sai com zero de largura: a faixa comia a
                  // altura toda e não pintava um pixel. Foi assim durante três
                  // afinações da altura, todas a medir uma faixa invisível.
                  width: double.infinity,
                  child: const ColoredBox(color: PunhoTheme.navyDeep),
                ),
              Expanded(
                child: Row(
                  children: [
                    _Sidebar(destinations: destinations, selected: destination),
                    // Na rotação contrária o furo fica à direita, do lado do
                    // conteúdo. A barra lateral já absorve o caso simétrico;
                    // aqui é o canvas que tem de se afastar da aresta.
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: MediaQuery.paddingOf(context).right,
                        ),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const BrandLockup(compact: true),
        actions: [
          if (!SupabaseConfig.enabled) const _ProfileSelector(),
          IconButton(
            tooltip: 'Conta',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => mostrarPerfil(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: _MobileMenu(destinations: destinations, selected: destination),
      ),
      body: content,
    );
  }
}

class _ProfileSelector extends ConsumerWidget {
  const _ProfileSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return DropdownButton<DemoRole>(
      value: role,
      underline: const SizedBox(),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: DemoRole.values
          .map(
            (x) => DropdownMenuItem(
              value: x,
              child: Text(switch (x) {
                DemoRole.manager => 'Gestor',
                DemoRole.collaboratorA => 'Colaborador A',
                DemoRole.collaboratorB => 'Colaborador B',
              }),
            ),
          )
          .toList(),
      onChanged: (x) => ref.read(demoSessionProvider.notifier).select(x!),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.destinations, required this.selected});
  final List<AppDestination> destinations;
  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    key: chaveDaBarraLateral,
    // 88 dp em vez de 72: passou a caber o rótulo debaixo do ícone. Com só
    // ícones, o rótulo dependia do tooltip — que num tablet só aparece com
    // toque longo, ou seja não aparece a quem está a aprender a app.
    //
    // Mais a margem esquerda: com o telemóvel deitado numa das rotações, o furo
    // da câmara fica desse lado e o `SafeArea` de baixo empurra o conteúdo para
    // dentro. Sem somar aqui, os 88 dp passavam a 54 e os rótulos apertavam —
    // a barra ficava diferente conforme o lado para que se roda o telemóvel.
    width: 88 + MediaQuery.paddingOf(context).left,
    color: PunhoTheme.navyDeep,
    child: SafeArea(
      top: false,
      // A margem direita é a barra de navegação do sistema, do outro lado do
      // ecrã. Esta barra está encostada à esquerda e o seu lado direito é
      // interior — quem tem de se afastar da barra de navegação é o conteúdo.
      // Sem este `false`, os 47 dp da barra de navegação saíam dos 88 da barra
      // lateral e os rótulos passavam a "P…", "Cli…", "Má…".
      right: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Espaço acima e abaixo da marca.
            //
            // Esteve em 4 dp e ficou mal: a marca encostava à moldura escura e
            // o primeiro botão vinha logo a seguir, sem respiro — o Cesar
            // descreveu-o como "um corte rente aos botões" que tirou harmonia à
            // barra. Aqueles 8 dp poupados não valiam a altura que davam.
            //
            // Isto é a barra **vertical**. A faixa escura do topo é outra coisa
            // e não encolhe: é ela que põe as notificações em fundo escuro.
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Transform.scale(
                    // Remove a margem branca do ficheiro de conceito sem
                    // alterar o tamanho reservado para a marca.
                    scale: 1.12,
                    child: Image.asset(
                      'assets/brand/punho_elo_operacao_v010.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Labels de secção ("CENTRO DE COMANDO", "OPERAÇÃO") removidos:
          // Cesar validou no smoke que os ícones + rótulos já são suficientes
          // e as labels só ocupavam altura sem valor informativo real.
          Expanded(
            child: ListView(
              // 3 dp de cada lado. Os botões ocupavam a largura toda da barra e
              // ficavam rentes às margens — o Cesar leu isso como falta de
              // centragem, e é: sem folga não há nada a centrar. Só aqui, para
              // o realce do item seleccionado continuar a começar na margem
              // esquerda da barra.
              padding: const EdgeInsets.symmetric(horizontal: 3),
              children: [
                for (final item in destinations)
                  _SidebarItem(
                    item: item,
                    selected: selected == item,
                    onTap: () =>
                        ref.read(navigationProvider.notifier).goTo(item),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFF203A4D)),
                ),
                const _PerfilSidebarItem(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PerfilSidebarItem extends StatelessWidget {
  const _PerfilSidebarItem();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: chaveDoAvatarDoPerfil,
        onTap: () => mostrarPerfil(context),
        borderRadius: BorderRadius.circular(10),
        // Sem `const` na moldura: o rótulo da versão lê o `PackageInfo` em
        // runtime, portanto a subárvore deixou de poder ser constante. Cada
        // filho fixo leva o seu `const`.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: Color(0xFFB7C7D1),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB7C7D1),
                  ),
                ),
                const SizedBox(height: 1),
                VersaoApp(
                  formato: (versao) => 'v $versao',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7F98A8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarItem extends ConsumerWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Só Tarefas leva contagem. Um badge em cada área deixaria de chamar a
    // atenção a nada.
    final pendentes = item == AppDestination.tasks
        ? ref.watch(contagemTarefasPendentesProvider)
        : 0;
    final urgente =
        item == AppDestination.tasks && ref.watch(tarefasTemUrgenteProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2B4A5E) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? const Border(
                      left: BorderSide(color: PunhoTheme.orange, width: 3),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? PunhoTheme.orange
                              : const Color(0xFFB7C7D1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? PunhoTheme.orange
                                : const Color(0xFFB7C7D1),
                          ),
                        ),
                      ],
                    ),
                    if (pendentes > 0)
                      Positioned(
                        top: -2,
                        right: 4,
                        child: _Badge(quantidade: pendentes, urgente: urgente),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contagem de pendentes. Vermelho só quando há algo urgente — um badge
/// vermelho permanente por causa de uma morada em falta deixa de significar
/// nada.
class _Badge extends StatelessWidget {
  const _Badge({required this.quantidade, required this.urgente});
  final int quantidade;
  final bool urgente;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 16),
    height: 16,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: urgente ? const Color(0xFFE24B4A) : const Color(0xFF4A5C68),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      quantidade > 9 ? '9+' : '$quantidade',
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
}

class _MobileMenu extends ConsumerWidget {
  const _MobileMenu({required this.destinations, required this.selected});
  final List<AppDestination> destinations;
  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: EdgeInsets.zero,
    children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: PunhoTheme.navyDeep),
        child: Align(
          alignment: Alignment.centerLeft,
          child: BrandLockup(emFundoEscuro: true),
        ),
      ),
      for (final item in destinations)
        ListTile(
          selected: item == selected,
          selectedTileColor: const Color(0xFFFFF1DA),
          leading: Icon(
            item.icon,
            color: item == selected ? PunhoTheme.orange : null,
          ),
          title: Text(item.label),
          onTap: () {
            ref.read(navigationProvider.notifier).goTo(item);
            Navigator.pop(context);
          },
        ),
    ],
  );
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({required this.destination});
  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    if (destination == AppDestination.management) return const DashboardPage();
    if (destination == AppDestination.semana) return const MinhaSemanaPage();
    if (destination == AppDestination.machines) return const MachinesPage();
    if (destination == AppDestination.clients) return const ClientsPage();
    if (destination == AppDestination.bookings) return const BookingsPage();
    if (destination == AppDestination.tasks) return const TarefasPage();
    if (destination == AppDestination.employees) {
      return const CollaboratorsPage();
    }
    if (destination == AppDestination.empresa) return const EmpresaPage();
    // Finanças e Veículos deixaram de ser destinos da barra, mas quem lá for
    // ter — por uma tarefa antiga, por código que ainda os nomeie — abre a
    // Empresa na aba certa, em vez de encontrar um ecrã vazio.
    final aba = destination.abaDeEmpresa;
    if (aba != null) return EmpresaPage(abaInicial: aba);
    return _EmptyPage(destination: destination);
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.destination});
  final AppDestination destination;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            destination.icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            destination.label,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Este espaço está preparado para a próxima fase.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
