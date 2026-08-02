/// Conversões entre o texto de um campo e o valor guardado.
///
/// Os mesmos quatro ajudantes existem, privados, em `operational_pages.dart`.
/// Ficam aqui em público para o ecrã de Definições os poder usar sem mexer
/// naquele ficheiro — quando o onboarding assentar, aquele passa a importar
/// estes e os privados saem.
library;

/// Texto de um campo opcional: em branco quer dizer "sem valor", não "vazio".
String? textoOpcional(String valor) {
  final limpo = valor.trim();
  return limpo.isEmpty ? null : limpo;
}

/// Lê euros escritos à portuguesa ("1.234,56" ou "1234.56") em cêntimos.
/// Devolve `null` para vazio ou impossível — nunca um zero inventado.
int? centsDeTexto(String valor) {
  final cru = valor.trim().replaceAll(' ', '');
  if (cru.isEmpty) return null;
  final normalizado = cru.contains(',')
      ? cru.replaceAll('.', '').replaceAll(',', '.')
      : cru;
  final montante = double.tryParse(normalizado);
  return montante == null || montante < 0 ? null : (montante * 100).round();
}

/// Cêntimos em texto para mostrar num campo. `null` fica em branco.
String textoDeCents(int? cents) =>
    cents == null ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

/// Contagens (colaboradores, veículos, máquinas). Em branco ou inválido conta
/// como zero: são números declarados, não valores opcionais.
int contagemDeTexto(String valor) {
  final parsed = int.tryParse(valor.trim());
  return parsed == null || parsed < 0 ? 0 : parsed;
}

/// Um NIF português válido em forma: exactamente 9 dígitos.
///
/// Não verifica o dígito de controlo — só a forma, que é o que a Edge
/// Function `sincronizar-empresa-punho` também exige (`nif.length < 9`
/// rejeita o payload inteiro com 400). Ficar aquém disso deixava fichas de
/// empresa presas para sempre com `dados={}` no Supabase.
bool nifValido(String valor) => RegExp(r'^\d{9}$').hasMatch(valor.trim());
