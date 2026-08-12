/// O que o arquivo da empresa aceita receber, e o nome técnico de cada coisa.
///
/// Existe por causa do achado 4: o balde `punho-documentos` aceitava **qualquer
/// tipo de ficheiro**. Fechá-lo do lado do servidor é uma linha; o que não é
/// uma linha é fechá-lo sem partir o envio de fotografias, e é isso que este
/// ficheiro trata.
///
/// O cliente do Supabase adivinha o tipo pela extensão do caminho local e, se
/// não reconhecer, manda `application/octet-stream` — que passa a ser recusado.
/// Uma fotografia com uma extensão invulgar deixaria de subir, e o utilizador
/// via um erro do servidor sem perceber porquê. Aqui decide-se antes: ou se
/// sabe dizer o que é, ou se recusa com uma frase que se entende.
library;

/// Extensão (sem ponto, minúsculas) → o que se declara ao arquivo.
///
/// A lista é a das câmaras e galerias de Android, mais o PDF. O PDF ainda não
/// tem por onde ser escolhido — os dois selectores da app pedem imagens — mas
/// um comprovativo de despesa em PDF é o próximo passo óbvio e é exactamente o
/// que um balde chamado «documentos» deve aceitar.
const Map<String, String> tiposAceites = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'pdf': 'application/pdf',
};

/// O tipo a declarar para este caminho, ou `null` se não se souber.
///
/// `null` não é um detalhe: é a diferença entre recusar aqui, com uma frase, e
/// deixar o servidor recusar com um 400.
String? tipoDoCaminho(String caminho) {
  final ficheiro = caminho.split('/').last;
  final ponto = ficheiro.lastIndexOf('.');
  if (ponto < 0 || ponto == ficheiro.length - 1) return null;
  return tiposAceites[ficheiro.substring(ponto + 1).toLowerCase()];
}

/// A frase que se mostra a quem escolheu um ficheiro que não serve.
///
/// Diz o que aconteceu e o que fazer, sem nome de código nem tipo MIME: quem
/// está a tentar fotografar uma factura não sabe o que é um `image/heif`.
String recusaDeTipo(String caminho) {
  final ficheiro = caminho.split('/').last;
  return 'Não é possível enviar "$ficheiro". O arquivo aceita fotografias '
      '(JPG, PNG, WEBP, HEIC) e PDF.';
}
