import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/estado_acesso.dart';

/// Convite gerado por um gestor, para partilhar por fora (não há envio de
/// emails nesta fase).
class Convite {
  final String codigo;
  final String email;
  final String perfil;
  final DateTime expiraEm;
  final bool usado;

  const Convite({
    required this.codigo,
    required this.email,
    required this.perfil,
    required this.expiraEm,
    this.usado = false,
  });

  factory Convite.fromJson(Map<String, dynamic> json) => Convite(
    codigo: json['codigo'] as String,
    email: (json['email'] as String?) ?? '',
    perfil: (json['perfil'] as String?) ?? 'colaborador',
    expiraEm: DateTime.parse(json['expira_em'] as String),
    usado: json['usado'] == true,
  );

  bool expiradoEm(DateTime agora) => !agora.isBefore(expiraEm);
  bool disponivelEm(DateTime agora) => !usado && !expiradoEm(agora);
}

/// Resultado da validação de um código de convite, antes do registo.
///
/// [bloqueado] vem do travão que o servidor põe a quem tenta muitos códigos
/// seguidos da mesma origem. Não é um erro de quem está a escrever — é o balde
/// do sítio inteiro a encher, porque a conta é por endereço de rede e numa
/// lavandaria todos partilham o mesmo.
enum ValidacaoConvite { valido, invalido, expirado, usado, bloqueado }

/// Código próprio para "este email já tem conta".
///
/// Não é um código do Supabase: é nosso, porque o Supabase **não devolve erro
/// nenhum** neste caso (ver [emailJaRegistado]). Serve para o `AuthException`
/// que criamos entrar no mesmo caminho de tradução de mensagens que os erros
/// reais, em vez de haver dois sítios a decidir o que se mostra.
const codigoEmailJaRegistado = 'punho_email_ja_registado';

/// O Supabase respondeu "sucesso" a um registo de um email que já existe?
///
/// Com a confirmação de email ligada, um `signUp` de um email já registado
/// devolve `200` com um utilizador obfuscado e **`identities` vazio** — é a
/// protecção contra enumeração de contas. Uma conta genuinamente nova traz
/// sempre pelo menos uma identidade.
///
/// Função separada e pública para se poder testar sem falar com o Supabase.
bool emailJaRegistado(AuthResponse resposta) {
  final utilizador = resposta.user;
  if (utilizador == null) return false;
  final identidades = utilizador.identities;
  return identidades != null && identidades.isEmpty;
}

extension ValidacaoConviteMensagem on ValidacaoConvite {
  /// Mensagem para o utilizador. Não distingue "não existe" de "de outra
  /// empresa" — não há nada a ganhar em dizê-lo.
  String? get mensagem => switch (this) {
    ValidacaoConvite.valido => null,
    ValidacaoConvite.expirado =>
      'Este código de convite já expirou. Pede um novo ao gestor.',
    ValidacaoConvite.usado =>
      'Este código de convite já foi utilizado. Pede um novo ao gestor.',
    ValidacaoConvite.invalido =>
      'Código de convite inválido, expirado ou já utilizado.',
    // Diz o que fazer, não o que aconteceu. Quem lê isto quase de certeza não
    // fez nada de mal: ou está a partilhar a rede com quem também se está a
    // registar, ou já tentou várias vezes seguidas. "Espera um quarto de hora"
    // é accionável; "excedeu o limite de tentativas" não é.
    ValidacaoConvite.bloqueado =>
      'Já foram tentados muitos códigos a partir desta rede. '
          'Espera 15 minutos e tenta outra vez, ou pede ao gestor '
          'que confirme o código.',
  };
}

/// Contrato de tudo o que a área de acessos precisa do servidor.
///
/// É uma interface fina de propósito: o repositório não tem package de mocking
/// e `SupabaseClient` é uma classe concreta com API encadeada, impossível de
/// fakear a sério. Os testes implementam isto; a produção usa
/// [SupabaseAcessoService].
abstract class AcessoService {
  /// Id da conta autenticada. Serve de identidade do colaborador nos registos
  /// que ele cria (leads, marcações, recebimentos).
  String? get utilizadorId;

  Future<EstadoAcesso> meuAcesso();
  Future<ValidacaoConvite> validarConvite(String codigo);

  /// [machineId] é o terminal de onde parte o pedido.
  ///
  /// Com `app`, forma o mesmo par que identifica um terminal em `licencas` — a
  /// chave que o WashInvoice já usava. É o que permite ao Control dizer de que
  /// aparelho veio um pedido e cruzá-lo com a instalação correspondente. Vai
  /// nulo quando ainda não se conseguiu resolver: nunca se inventa um.
  Future<void> registar({
    required String email,
    required String palavraPasse,
    required String nome,
    required String empresa,
    required String perfil,
    String? codigoConvite,
    String? machineId,
  });

  /// Pede acesso com a sessão já aberta, para quem não tem pedido nenhum.
  ///
  /// Devolve o estado em que a conta ficou: `pendente` quando o pedido foi
  /// criado, `membro` se afinal já havia adesão, ou o estado do pedido que já
  /// existia. Nunca cria um segundo.
  Future<String> pedirAcesso({
    required String nome,
    required String empresa,
    required String perfil,
    String? machineId,
  });

  Future<Convite> criarConvite({required String email, required String perfil});
  Future<List<Convite>> listarConvites();
  Future<void> terminarSessao();
}

class SupabaseAcessoService implements AcessoService {
  SupabaseAcessoService(this._client);
  final SupabaseClient _client;

  @override
  String? get utilizadorId => _client.auth.currentUser?.id;

  @override
  Future<EstadoAcesso> meuAcesso() async {
    final linhas = await _client.rpc('punho_meu_acesso') as List<dynamic>;
    if (linhas.isEmpty) {
      // Não devia acontecer — a função é um `select` sem `from` e devolve
      // sempre uma linha. Se acontecer, é ausência de informação e não um
      // pedido à espera: sem `estado`, o porteiro manda pedir acesso.
      return const EstadoAcesso(membroAtivo: false);
    }
    return EstadoAcesso.fromJson(linhas.first as Map<String, dynamic>);
  }

  @override
  Future<String> pedirAcesso({
    required String nome,
    required String empresa,
    required String perfil,
    String? machineId,
  }) async {
    // Quem é o requerente não vai daqui: o servidor tira-o de `auth.uid()` e o
    // email de `auth.users`. Deste lado só viaja o que a pessoa escreveu — e o
    // terminal, que é uma propriedade do aparelho e não uma afirmação sobre
    // quem ele é.
    final estado = await _client.rpc(
      'punho_pedir_acesso',
      params: {
        'p_nome': nome,
        'p_empresa': empresa,
        'p_perfil': perfil,
        'p_machine_id': machineId,
      },
    );
    return (estado as String?) ?? 'pendente';
  }

  @override
  Future<ValidacaoConvite> validarConvite(String codigo) async {
    final estado = await _client.rpc(
      'punho_validar_convite',
      params: {'p_codigo': codigo},
    );
    return switch (estado as String?) {
      'valido' => ValidacaoConvite.valido,
      'expirado' => ValidacaoConvite.expirado,
      'usado' => ValidacaoConvite.usado,
      'bloqueado' => ValidacaoConvite.bloqueado,
      _ => ValidacaoConvite.invalido,
    };
  }

  @override
  Future<void> registar({
    required String email,
    required String palavraPasse,
    required String nome,
    required String empresa,
    required String perfil,
    String? codigoConvite,
    String? machineId,
  }) async {
    // `app: 'punho'` é o que o trigger de auth.users usa para distinguir este
    // registo dos do POS, que partilham o mesmo projecto Supabase. Com o
    // `machine_id` ao lado, é também o par que identifica o terminal.
    final resposta = await _client.auth.signUp(
      email: email,
      password: palavraPasse,
      data: {
        'app': 'punho',
        'nome': nome,
        'empresa': empresa,
        'perfil': perfil,
        if (machineId != null && machineId.isNotEmpty) 'machine_id': machineId,
        if (codigoConvite != null && codigoConvite.isNotEmpty)
          'convite': codigoConvite,
      },
    );
    // Email já registado **não vem como erro**.
    //
    // Com a confirmação de email ligada, o Supabase protege-se contra
    // enumeração de contas: em vez de recusar, devolve sucesso com um
    // utilizador obfuscado e a lista de identidades **vazia**. Sem isto, quem
    // se tentasse registar com um email que já tem conta via "Conta criada" e
    // ficava à espera de um email que nunca chega.
    //
    // É esta a razão de o `mensagemSegura('user_already_exists')` nunca ter
    // disparado: o código estava lá, mas não havia excepção nenhuma para o
    // trazer.
    if (emailJaRegistado(resposta)) {
      throw const AuthException(
        'Email já registado',
        code: codigoEmailJaRegistado,
      );
    }
  }

  @override
  Future<Convite> criarConvite({
    required String email,
    required String perfil,
  }) async {
    final linhas =
        await _client.rpc(
              'punho_criar_convite',
              params: {'p_email': email, 'p_perfil': perfil},
            )
            as List<dynamic>;
    final linha = linhas.first as Map<String, dynamic>;
    return Convite(
      codigo: linha['codigo'] as String,
      email: email,
      perfil: perfil,
      expiraEm: DateTime.parse(linha['expira_em'] as String),
    );
  }

  @override
  Future<List<Convite>> listarConvites() async {
    // Os convites usados ficam na lista, portanto ela só cresce. Do mais
    // recente para o mais antigo e com tecto: quem abre este ecrã quer ver o
    // que acabou de enviar, não o convite de há três anos.
    final linhas = await _client
        .from('punho_convites')
        .select('codigo, email, perfil, expira_em, usado')
        .order('criado_em', ascending: false)
        .limit(200);
    return (linhas as List)
        .cast<Map<String, dynamic>>()
        .map(Convite.fromJson)
        .toList();
  }

  @override
  Future<void> terminarSessao() => _client.auth.signOut();
}
