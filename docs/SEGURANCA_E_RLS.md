# Segurança e RLS

Nunca coloque segredos administrativos no Flutter. Documentos devem usar bucket privado e URLs assinados quando o armazenamento remoto for implementado.

Os dados atuais ficam locais no dispositivo. A migration inclui RLS inicial, mas requer revisão e políticas completas antes de produção. Não existem Edge Functions, exportação, retenção, cópia de segurança ou apagamento de conta implementados nesta entrega.

Permissão de câmara só deve ser solicitada quando a funcionalidade Android real for adicionada e o utilizador escolher fotografar uma fatura.
