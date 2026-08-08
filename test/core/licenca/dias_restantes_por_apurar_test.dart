import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/licenca/licenca_info.dart';
import 'package:punho/features/licenca/presentation/licenca_banner.dart';

/// **Uma ausência não é um zero — e muito menos um alarme.**
///
/// `dias_restantes` em falta na resposta do servidor virava `0`, porque o
/// conversor devolvia zero no caso por omissão. O banner lia esse zero como
/// facto e anunciava **"Trial termina em 0 dias — contactar já"** a um cliente
/// com 60 dias pela frente.
///
/// Um alarme falso é pior do que nenhum aviso: ensina o utilizador a ignorar
/// os avisos todos, incluindo o que um dia for verdadeiro.
void main() {
  LicencaInfo licenca({
    EstadoLicenca estado = EstadoLicenca.activa,
    String? plano = 'trial',
    int? dias,
  }) => LicencaInfo(
    estado: estado,
    machineId: 'm1',
    plano: plano,
    diasRestantes: dias,
  );

  group('o que vem do servidor', () {
    test('sem dias_restantes, fica null — nunca zero', () {
      final info = LicencaInfo.fromJson(const {
        'estado': 'activa',
        'plano': 'trial',
      }, machineId: 'm1');
      expect(info.diasRestantes, isNull);
    });

    test('com dias_restantes, lê-o — incluindo em texto', () {
      expect(
        LicencaInfo.fromJson(const {
          'estado': 'activa',
          'dias_restantes': 12,
        }).diasRestantes,
        12,
      );
      expect(
        LicencaInfo.fromJson(const {
          'estado': 'activa',
          'dias_restantes': '7',
        }).diasRestantes,
        7,
      );
    });

    test('um zero verdadeiro continua a ser zero', () {
      // A distinção é toda esta: o servidor **dizer** zero é diferente de o
      // servidor não dizer nada.
      expect(
        LicencaInfo.fromJson(const {
          'estado': 'activa',
          'dias_restantes': 0,
        }).diasRestantes,
        0,
      );
    });
  });

  group('o banner', () {
    test('sem dias declarados não inventa contagem nenhuma', () {
      expect(avisoParaLicenca(licenca(dias: null)), isNull);
    });

    test('o alarme falso da v0.0.x já não acontece', () {
      final aviso = avisoParaLicenca(licenca(dias: null));
      expect(aviso?.mensagem, isNot(contains('0 dias')));
      expect(aviso?.mensagem, isNot(contains('contactar já')));
    });

    test('com poucos dias mesmo, avisa — o aviso verdadeiro fica de pé', () {
      final aviso = avisoParaLicenca(licenca(dias: 2));
      expect(aviso, isNotNull);
      expect(aviso!.mensagem, contains('contactar já'));
    });

    test('com o trial longe, não incomoda', () {
      expect(avisoParaLicenca(licenca(dias: 30)), isNull);
    });

    test('licença expirada não promete um modo limitado que não existe', () {
      // `LicencaInfo.funcional` não tem um único consumidor: nada na app está
      // restringido. Prometer a limitação era ensinar a ignorar o aviso.
      final aviso = avisoParaLicenca(
        licenca(estado: EstadoLicenca.expirada, plano: 'mensal'),
      );
      expect(aviso, isNotNull);
      expect(aviso!.mensagem, isNot(contains('modo limitado')));
      expect(aviso.mensagem, contains('Licença expirada'));
    });
  });
}
