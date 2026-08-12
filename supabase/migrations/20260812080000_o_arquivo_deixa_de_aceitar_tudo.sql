-- Achado 4 — `punho-documentos` aceitava qualquer tipo de ficheiro.
--
-- É o balde onde vivem as fotografias das máquinas e os comprovativos de
-- despesa, e onde qualquer membro de uma empresa pode escrever. Sem lista de
-- tipos, o limite era só o tamanho: 20 MB de o que fosse. Um APK, uma página
-- HTML, um executável — tudo entrava, e ficava a ser servido por um endereço
-- assinado que a própria app distribui aos colegas.
--
-- A lista é a das câmaras e galerias de Android, mais o PDF. O PDF ainda não
-- tem por onde ser escolhido (os dois selectores da app pedem imagens), mas um
-- comprovativo em PDF é o próximo passo óbvio e é o que um balde chamado
-- «documentos» deve aceitar.
--
-- Provado contra o servidor a sério, e sem precisar de sessão nenhuma — o
-- controlo do tipo corre **antes** da autorização:
--
--   application/vnd.android.package-archive → 415 invalid_mime_type
--   image/png                               → passa o tipo, e só depois esbarra
--                                             na RLS ("new row violates ...")
--
-- Do lado da app, `lib/core/media/tipos_aceites.dart`: o cliente do Supabase
-- adivinha o tipo pela extensão do caminho local e cai em
-- `application/octet-stream` quando não reconhece — que passou a ser recusado.
-- Uma fotografia com extensão invulgar deixaria de subir com um 415 que não
-- explica nada. Agora decide-se antes, e recusa-se com uma frase.

update storage.buckets
   set allowed_mime_types = array[
     'image/jpeg','image/png','image/webp','image/heic','image/heif',
     'image/gif','image/bmp','application/pdf'
   ]
 where id = 'punho-documentos';

-- E o balde `releases`, que ficou de trás.
--
-- Era público e tem lá três APKs do Punho v0.0.6, de 27 de Julho, esquecidos
-- quando a publicação passou para as Releases do GitHub. Nenhuma linha de
-- `versoes_apps` aponta para lá — verificado, as 54 apontam todas para o GitHub
-- —, portanto era só isto: um endereço público de onde qualquer pessoa
-- descarrega uma versão velha da app.
--
-- Passa a privado, que é reversível numa linha. **Os ficheiros não se apagam
-- aqui**: apagar é irreversível e a decisão é do César.
update storage.buckets set public = false where id = 'releases';
