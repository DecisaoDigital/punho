// Validação de formato dos contactos de um cliente. Só diz se parece um
// telemóvel / email; não prova que existem.

/// `null` se o telemóvel é aceitável, senão a mensagem para o utilizador.
///
/// Aceita números portugueses (9 dígitos, a começar por 2 ou 9, com ou sem
/// `+351`/`00351`, espaços ou hífenes) e internacionais com `+` ou `00`
/// (8 a 15 dígitos).
String? erroDeTelemovel(String valor) {
  final texto = valor.trim();
  if (RegExp(r'[^0-9+\s\-().]').hasMatch(texto)) {
    return 'O telemóvel só pode ter números (ex.: 912 345 678).';
  }
  var digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  final internacional = texto.startsWith('+') || digitos.startsWith('00');
  if (internacional) {
    if (!texto.startsWith('+')) digitos = digitos.substring(2);
    if (digitos.startsWith('351')) {
      digitos = digitos.substring(3);
    } else if (digitos.length >= 8 && digitos.length <= 15) {
      return null;
    }
  }
  if (RegExp(r'^[29]\d{8}$').hasMatch(digitos)) return null;
  return 'Telemóvel inválido — 9 dígitos, ex.: 912 345 678.';
}

/// `null` se o email tem formato aceitável (ou está vazio, por ser opcional).
String? erroDeEmail(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return null;
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@.]{2,}$').hasMatch(texto)) {
    return 'Email inválido — ex.: nome@dominio.pt.';
  }
  return null;
}

/// `null` se o NIF está vazio (opcional) ou tem 9 dígitos.
String? erroDeNif(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return null;
  if (!RegExp(r'^\d{9}$').hasMatch(texto)) {
    return 'O NIF tem 9 dígitos.';
  }
  return null;
}
