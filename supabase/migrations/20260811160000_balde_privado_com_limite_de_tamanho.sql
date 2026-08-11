-- O balde `punho-documentos` aceitava ficheiros de qualquer tamanho.
--
-- Achado 3.7 da auditoria de 11/8, que estava marcado como «por verificar». As
-- políticas do `storage.objects` estão bem — cada empresa só chega à sua pasta,
-- os comprovativos de despesa só são lidos pelo autor ou por um gestor, e a
-- leitura das fotografias de máquinas exige ser membro activo. O que faltava
-- era o outro lado: `file_size_limit` a null.
--
-- Qualquer membro de qualquer empresa podia enviar um ficheiro de 900 MB para
-- a sua pasta. O plano tem 1 GB para tudo — e nesse tudo está o balde
-- `releases`, de onde saem os APKs. Uma pessoa distraída, ou uma zangada,
-- deixava o projecto inteiro sem espaço, e a primeira coisa a partir era a
-- actualização das apps de toda a gente.
--
-- 20 MB é folgado para o que lá entra de verdade: fotografias com 1800 px de
-- largura e qualidade 85, que dão umas centenas de kB, e comprovativos de
-- despesa. Deixa de ser «um ficheiro chega para encher o projecto» e passa a
-- precisar de cinquenta.
--
-- ## O que não se faz aqui
--
-- Não se restringem os tipos de ficheiro (`allowed_mime_types`). Devia
-- restringir-se — só imagens e PDF entram ali —, mas a restrição é feita contra
-- o `content-type` que o cliente declara, e se a inferência do tipo falhar num
-- caso qualquer o envio passa a ser recusado em produção. Isso não se mete sem
-- ser experimentado no aparelho.

update storage.buckets
   set file_size_limit = 20971520  -- 20 MB
 where id = 'punho-documentos'
   and file_size_limit is null;
