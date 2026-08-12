import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/media/tipos_aceites.dart';

/// Achado 4 — o balde `punho-documentos` aceitava qualquer tipo de ficheiro.
///
/// Fechá-lo do lado do servidor foi uma linha. O que este ficheiro guarda é a
/// outra metade: o cliente do Supabase adivinha o tipo pela extensão e cai em
/// `application/octet-stream` quando não reconhece — que passou a ser recusado
/// com 415. Sem decidir aqui, uma fotografia com extensão invulgar deixava de
/// subir e o utilizador via um erro do servidor sem perceber porquê.
void main() {
  group('o tipo que se declara ao arquivo', () {
    test('as fotografias que uma câmara de Android produz', () {
      expect(tipoDoCaminho('/cache/foto.jpg'), 'image/jpeg');
      expect(tipoDoCaminho('/cache/foto.jpeg'), 'image/jpeg');
      expect(tipoDoCaminho('/cache/captura.png'), 'image/png');
      expect(tipoDoCaminho('/cache/imagem.webp'), 'image/webp');
      // O formato por omissão de meio telemóvel moderno. Fica de fora de muita
      // lista escrita à pressa, e é o que mais depressa se nota.
      expect(tipoDoCaminho('/cache/IMG_0001.heic'), 'image/heic');
      expect(tipoDoCaminho('/cache/IMG_0002.heif'), 'image/heif');
    });

    test('o PDF, que é o comprovativo que ainda não se pode escolher', () {
      expect(tipoDoCaminho('/downloads/factura.pdf'), 'application/pdf');
    });

    test('a extensão em maiúsculas é a mesma extensão', () {
      // `DCIM/IMG_1234.JPG` é como a câmara escreve, e um mapa sensível a
      // maiúsculas recusava-a.
      expect(tipoDoCaminho('/DCIM/IMG_1234.JPG'), 'image/jpeg');
      expect(tipoDoCaminho('/DCIM/foto.HEIC'), 'image/heic');
    });

    test('o que não se sabe nomear devolve null, e não um palpite', () {
      // Um palpite aqui seria mentir ao arquivo sobre o que lá está a entrar.
      expect(tipoDoCaminho('/tmp/instalador.apk'), isNull);
      expect(tipoDoCaminho('/tmp/pagina.html'), isNull);
      expect(tipoDoCaminho('/tmp/ficheiro_sem_extensao'), isNull);
      expect(tipoDoCaminho('/tmp/acaba.em.ponto.'), isNull);
      expect(tipoDoCaminho(''), isNull);
    });

    test('um ponto na pasta não conta como extensão do ficheiro', () {
      // `/uma.pasta/ficheiro` tem um ponto no caminho e nenhum no nome. Quem
      // procurar o último ponto do caminho inteiro lê "pasta/ficheiro" como
      // extensão e devolve lixo.
      expect(tipoDoCaminho('/uma.pasta/ficheiro'), isNull);
      expect(tipoDoCaminho('/uma.pasta/foto.png'), 'image/png');
    });
  });

  group('a frase de recusa', () {
    test('nomeia o ficheiro e diz o que serve', () {
      final frase = recusaDeTipo('/storage/emulated/0/Download/manual.docx');

      expect(frase, contains('manual.docx'));
      expect(frase, contains('JPG'));
      expect(frase, contains('PDF'));
      // Sem jargão: quem está a fotografar uma factura não sabe o que é um
      // `image/heif`.
      expect(frase, isNot(contains('image/')));
      expect(frase, isNot(contains('MIME')));
    });
  });

  test('tudo o que o mapa aceita tem um tipo não vazio', () {
    // Uma entrada com valor vazio passava a validação do `null` e ia declarar
    // um `Content-Type:` em branco ao arquivo.
    for (final entrada in tiposAceites.entries) {
      expect(entrada.value, isNotEmpty, reason: 'a extensão ${entrada.key}');
      expect(entrada.value, contains('/'), reason: 'a extensão ${entrada.key}');
      expect(entrada.key, equals(entrada.key.toLowerCase()));
    }
  });
}
