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
///
/// O caso que obrigou a olhar para isto foi `1.200` sem casas decimais: mil e
/// duzentos euros, ou um euro e vinte? Esta função lia-o como 1,20 €, porque
/// tratava qualquer ponto como decimal. Quem escreve `1.200` em Portugal está a
/// escrever mil e duzentos, e ficava com um valor cem vezes menor sem nada o
/// avisar — um erro que não rebenta, grava-se em silêncio e aparece meses
/// depois num painel que ninguém percebe porque está errado.
///
/// A regra que decide, e que é a mesma do portal do contabilista
/// (`supabase/functions/portal-contabilista/euros.ts`):
///
///  * há vírgula → a vírgula é o decimal e os pontos são milhares;
///  * só pontos, a separar grupos de exactamente três dígitos → são milhares;
///  * qualquer outro ponto → é decimal, que é como escreve quem copiou de uma
///    folha de cálculo inglesa.
///
/// Tem de ser a mesma regra nos dois sítios. O contabilista e o gestor escrevem
/// no mesmo histórico, e um `1.200` que valesse coisas diferentes conforme quem
/// o escreveu era o mesmo campo com dois significados.
///
/// [permitirNegativo] existe para o histórico contabilístico, onde uma nota de
/// crédito faz um mês valer menos que zero. Fica desligado por omissão: nos
/// restantes campos — preços, salários, custos — um negativo é engano, e
/// recusá-lo é melhor do que guardá-lo.
int? centsDeTexto(String valor, {bool permitirNegativo = false}) {
  final cru = valor.replaceAll(RegExp(r'[\s €]'), '');
  if (cru.isEmpty) return null;

  final String normalizado;
  if (cru.contains(',')) {
    normalizado = cru.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(cru)) {
    normalizado = cru.replaceAll('.', '');
  } else {
    normalizado = cru;
  }

  final montante = double.tryParse(normalizado);
  if (montante == null || !montante.isFinite) return null;
  if (montante < 0 && !permitirNegativo) return null;
  return (montante * 100).round();
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
