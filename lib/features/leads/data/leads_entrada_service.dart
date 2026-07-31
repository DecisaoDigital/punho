import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/operations.dart';

/// Uma lead que chegou de fora e ainda não entrou no pipeline local.
///
/// Ver `docs/ENTRADA_DE_LEADS.md`. O servidor já classificou: `aceite` entra
/// sem ninguém aprovar, `retida` espera um toque, `descartada` nunca chega aqui.
class LeadEntrada {
  const LeadEntrada({
    required this.id,
    required this.origem,
    required this.classificacao,
    required this.recebidaEm,
    this.nome,
    this.telefone,
    this.email,
    this.mensagem,
    this.motivo,
  });

  final String id;
  final LeadSource origem;
  final String classificacao;
  final DateTime recebidaEm;
  final String? nome, telefone, email, mensagem, motivo;

  bool get aceite => classificacao == 'aceite';

  /// Sem nome, o telefone identifica melhor do que "Lead" — é o que o gestor vê
  /// na lista antes de ligar.
  String get nomeParaMostrar {
    final n = nome?.trim();
    if (n != null && n.isNotEmpty) return n;
    return telefone ?? email ?? 'Contacto sem nome';
  }

  factory LeadEntrada.fromJson(Map<String, dynamic> json) => LeadEntrada(
    id: json['id'] as String,
    origem: _origem(json['origem'] as String?),
    classificacao: (json['classificacao'] as String?) ?? 'retida',
    recebidaEm:
        DateTime.tryParse(json['recebida_em'] as String? ?? '') ??
        DateTime.now(),
    nome: json['nome'] as String?,
    telefone:
        json['telefone_e164'] as String? ??
        json['telefone_original'] as String?,
    email: json['email'] as String?,
    mensagem: json['mensagem'] as String?,
    motivo: json['motivo'] as String?,
  );

  static LeadSource _origem(String? bruto) => switch (bruto) {
    'landing_page' => LeadSource.landingPage,
    'whatsapp' => LeadSource.whatsapp,
    'telefone' => LeadSource.call,
    'agenda' => LeadSource.agenda,
    _ => LeadSource.other,
  };

  /// Converte para a lead local do pipeline.
  ///
  /// O `createdAt` é o momento em que **chegou**, não o momento em que a app a
  /// puxou: é o que faz o "sem contacto há mais de N dias" contar o tempo de
  /// resposta a sério, que é a métrica que interessa nesta alavanca.
  Lead paraLead(String id) => Lead(
    id: id,
    name: nomeParaMostrar,
    phone: telefone ?? '',
    status: LeadStatus.newLead,
    createdAt: recebidaEm,
    source: origem,
    summary: mensagem ?? '',
  );
}

/// Lê a caixa de entrada no Supabase e marca o que já foi processado.
///
/// Não filtra por empresa: a política de RLS já só devolve as linhas da empresa
/// de quem está autenticado. Filtrar outra vez aqui seria duplicar a regra em
/// dois sítios, e é a cópia que fica desactualizada.
class LeadsEntradaService {
  LeadsEntradaService(this._cliente);
  final SupabaseClient _cliente;

  static const _tabela = 'punho_leads_entrada';

  Future<List<LeadEntrada>> porProcessar() async {
    try {
      final linhas = await _cliente
          .from(_tabela)
          .select()
          .isFilter('processada_em', null)
          .neq('classificacao', 'descartada')
          .order('recebida_em');
      return (linhas as List)
          .map((l) => LeadEntrada.fromJson(Map<String, dynamic>.from(l as Map)))
          .toList();
    } catch (erro) {
      // Falha em silêncio para o utilizador, com rasto nos logs: uma caixa de
      // entrada que não abre não pode impedir a app de funcionar.
      debugPrint('[LeadsEntrada] leitura falhou: $erro');
      return const [];
    }
  }

  /// Marca como processada. `leadLocalId` liga a linha do servidor à lead que
  /// lhe deu origem, para se poder responder a "de onde veio esta lead?".
  Future<bool> marcarProcessada(String id, {String? leadLocalId}) async {
    try {
      await _cliente
          .from(_tabela)
          .update({
            'processada_em': DateTime.now().toUtc().toIso8601String(),
            if (leadLocalId != null) 'lead_local_id': leadLocalId,
          })
          .eq('id', id);
      return true;
    } catch (erro) {
      debugPrint('[LeadsEntrada] marcar processada falhou: $erro');
      return false;
    }
  }
}
