# Checklist de implementação — Punho

Última revisão: 25 de julho de 2026.

Legenda: `[x]` concluído e validado localmente; `[-]` iniciado/parcial; `[ ]` por implementar ou activar.

## 1. Base de produto e experiência

- [x] Nome, posicionamento e assinatura: **Punho — Agarra o comando.**
- [x] Identidade inicial: azul-noite, branco e laranja/dourado de acção.
- [x] Moldura de gestão com barra lateral, ícones, item activo e áreas de comando/operação.
- [x] Orientação horizontal para o painel do empresário/administrador em telemóvel e tablet.
- [x] Ecrã de colaborador simples, em retrato, para registos rápidos.
- [-] Redesenhar todos os ecrãs internos com a mesma linguagem premium da nova moldura (cartões, tabelas, filtros, estados e vazios).
- [ ] Criar um sistema visual completo: tipografia, espaçamentos, chips de estado, alertas, gráficos e componentes reutilizáveis.
- [ ] Validar a experiência num tablet Android real, em telemóvel pequeno e em Windows.

## 2. Onboarding que ensina a gerir

- [x] Perguntas iniciais sobre empresa, frota, colaboradores e número de máquinas.
- [x] Máquinas declaradas não são apresentadas como disponíveis enquanto não forem identificadas.
- [-] Guião progressivo de aprendizagem: o que registar hoje, o que analisar esta semana e o que fechar no fim do mês.
- [ ] Perguntas condicionais completas para despesas fixas, impostos, seguros, prestações, publicidade e manutenção anual estimada.
- [ ] Indicador de qualidade dos dados: mostrar claramente o que ainda está "por apurar" antes de tirar conclusões.
- [ ] Tarefas de onboarding com progresso: identificar máquinas, fotografar frota, configurar custos e introduzir clientes.

## 3. Máquinas e frota de aluguer

- [x] Máquinas com nome, código/número de série, categoria, estado, preço diário e notas.
- [x] Fotografias locais: câmara Android/iOS, galeria e selecção de ficheiro Windows; primeira imagem usada como capa.
- [x] Estado disponível, reservada, alugada, manutenção ou parada.
- [x] Associação de máquinas a reservas e prevenção de conflito básico de datas.
- [-] Guardar fotografias em cada dispositivo; falta sincronização privada entre dispositivos.
- [ ] Ficha completa da máquina: fabricante, modelo, data de compra, custo, valor actual, horas/quilómetros e documentos.
- [ ] Histórico de manutenção, avarias, peças, custos e fotos de antes/depois.
- [ ] Alertas de manutenção por data, horas de uso ou número de alugueres.
- [ ] QR code/código de barras por máquina para identificação no terreno.
- [ ] Check-in/check-out com fotografias, assinatura e confirmação de estado.
- [ ] Utilização e rentabilidade por máquina: dias alugados, dias parados, receita, manutenção e margem estimada.

## 4. Clientes, leads e reservas

- [x] Base de clientes e leads local da empresa.
- [x] Reserva com cliente, máquina, datas, valor esperado, estado e colaborador responsável.
- [x] Estados de reserva e validação de sobreposição básica.
- [-] Base de clientes partilhada está prevista no modelo, mas ainda não está sincronizada entre dispositivos reais.
- [ ] Calendário visual diário/semanal de reservas, entregas e recolhas.
- [ ] Pesquisa, filtros, histórico de cliente e histórico de máquina.
- [ ] Orçamentos, contratos, confirmação por cliente, depósitos e assinaturas.
- [ ] Lembretes de devolução, atrasos e cobrança de valores vencidos.
- [ ] Gestão de disponibilidade por quantidade para modelos com várias unidades iguais.

## 5. Dinheiro e gestão ensinada

- [x] Registo de recebimentos e despesas, incluindo despesas por pagar.
- [x] Categorias simples, incluindo refeições sem necessidade de justificar contexto.
- [x] Associação opcional de despesa a máquina ou veículo e de recebimento a cliente/reserva.
- [x] Indicadores básicos: recebido, pago, por receber, por pagar e resultado operacional simples.
- [-] Sugestões determinísticas iniciais com base em reservas, máquinas, despesas e recebimentos.
- [ ] Aprovação de despesas submetidas por colaborador: aprovar, devolver, pagar e manter histórico.
- [ ] Fluxo real de factura: tirar fotografia, ler QR/OCR, confirmar comerciante/valor/categoria e guardar comprovativo.
- [ ] Custos fixos recorrentes e previsão mensal de tesouraria.
- [ ] Resultado por reserva, por cliente, por máquina, por colaborador e por período.
- [ ] ROI de publicidade: investimento, origem da lead, reserva gerada, receita e retorno.
- [ ] Recomendações completas: cobrar atrasos e criar leads; promoções em dias fracos; avisos de margem baixa — sempre como sugestão, nunca automática.
- [ ] Exportação para contabilista (CSV/PDF) e integração contabilística, se for necessária.

## 6. Colaboradores

- [x] Colaboradores com limite activo, custo e horário previsto.
- [x] Modo local de colaborador para registar leads, reservas, recebimentos e despesas/facturas.
- [x] Despesa registada por colaborador nasce como "por pagar/por validar".
- [-] Cálculos de custo/resultado atribuível existem, mas não representam ainda lucro final do colaborador.
- [ ] Autenticação real de cada colaborador e encaminhamento automático para o modo de colaborador.
- [ ] Permissões reais: colaborador sem custos, margens, total financeiro ou configurações da empresa.
- [ ] Sincronização granular: colaborador envia apenas leads, reservas, recebimentos e despesas autorizados; gestor recebe tudo.
- [ ] Folha de ponto/check-in, se a empresa decidir que precisa dela.
- [ ] Relatório de actividade e desempenho por colaborador sem conclusões enganosas sobre lucro.

## 7. Dados reais, Supabase e segurança

- [x] Supabase configurável por `--dart-define`, ecrã de autenticação e RPC de criação inicial de empresa.
- [x] Migrations, RLS inicial, verificação SQL e protecções de integridade já documentadas.
- [x] Persistência local de operações e outbox/modelos de idempotência iniciais.
- [-] Sincronização de estado operacional do gestor preparada por snapshot; não validada contra uma base Supabase real.
- [ ] Aplicar todas as migrations na base Supabase real e validar RLS com duas empresas e dois perfis.
- [ ] Substituir os repositórios operacionais locais por repositórios Supabase com `empresa_id` em todas as consultas.
- [ ] Sincronização granular e offline real, com fila persistente, repetição, conflitos visíveis e resolução sem perda de dados.
- [ ] Supabase Storage privado para fotografias de máquinas, facturas e documentos; URLs assinados e regras por empresa.
- [ ] Upload em segundo plano, limites de tamanho, compressão, eliminação segura e recuperação de falhas.
- [ ] Backup, retenção, exportação/apagamento de dados e política de privacidade/RGPD.

## 8. WashInvoice Control e comercialização

- [x] Estrutura inicial de consulta de actualizações remotas pelo Control para a app `punho`.
- [x] Migration de catálogo de versões com plataforma e banner de actualização no Punho.
- [-] Código preparado; falta aplicar SQL e publicar a Edge Function no ambiente real.
- [ ] No Control: criar/editar planos Punho, empresa, estado da subscrição e data de validade.
- [ ] No Control: definir limite de colaboradores por empresa e packs (gestor + até 3 colaboradores, ou outros planos).
- [ ] No Punho: consultar autorização do Control no arranque e impedir exceder limites sem desactivar silenciosamente pessoas.
- [ ] Bloqueios claros por subscrição expirada, período de graça e reactivação.
- [ ] Registo de instalações/dispositivos e diagnóstico remoto mínimo, sem expor dados financeiros.

## 9. Distribuição e qualidade

- [x] Análise Flutter sem erros e testes unitários actuais passam localmente.
- [x] Build Windows tinha sido validado antes das últimas alterações funcionais.
- [-] Novo build Windows após as fotografias iniciou, mas não terminou no limite de execução disponível; precisa de confirmação local.
- [ ] Gerar e instalar APK Android num dispositivo real; testar câmara, galeria, horizontal do gestor e retrato do colaborador.
- [ ] Testar iOS/iPad real, permissões de câmara/galeria e orientação.
- [ ] Configurar GitHub: repositório Punho, branches, releases, changelog e pipeline de análise/testes/build.
- [ ] Assinatura de Android, distribuição de teste (APK/Play Internal Testing) e processo de versão.
- [ ] Testes de integração para autenticação, RLS, duas empresas, reservas simultâneas, offline e sincronização.
- [ ] Auditoria manual com uma empresa-piloto apenas com dados de demonstração antes de introduzir dados reais.

## Ordem recomendada para avançar

1. Activar Supabase real: migrations, RLS e uma conta gestor de teste.
2. Ligar repositórios Supabase e sincronização granular antes de convidar colaboradores.
3. Implementar Storage privado para fotografias e facturas.
4. Ligar perfis/permissões reais e os limites comerciais vindos do WashInvoice Control.
5. Terminar calendário, manutenção, check-in/check-out e gestão de reservas.
6. Completar tesouraria, aprovações, OCR de facturas e recomendações de gestão.
7. Executar piloto controlado em tablet/Android e corrigir fricções reais.
8. Só depois preparar distribuição comercial, actualizações remotas e cobrança.
