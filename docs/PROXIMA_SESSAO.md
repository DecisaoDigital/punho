# Próxima sessão — ponto de partida

Escrito a 5 de Agosto de 2026, no fim de uma sessão de brainstorm.
Actualizado no mesmo dia, depois de o plano começar a ser executado.

## Feito

- **`test/features/formularios/redmi_deitado_test.dart`** — 40 testes que
  correm os seis formulários à medida do Redmi deitado com o teclado aberto
  (872,7 × 392,7 dp, teclado 200,4, sobram 192,3). Apanharam três defeitos
  reais, todos corrigidos: 19 `DropdownButtonFormField` sem `isExpanded` que
  transbordavam em coluna estreita, seis campos de dinheiro com o teclado de
  inteiros do Android — sem vírgula, cêntimos impossíveis de escrever — e o
  filtro de caracteres das Definições, que comparava instâncias de
  `TextInputType` e caía em silêncio nos campos de euros.
- **Recados do contabilista** — a caixa do fim do portal gravava em
  `punho_mensagens_contabilista` e nenhum ecrã lia. Passa a aparecer no
  histórico do contabilista, realçada por ler, marcada por lida ao ser vista.
  `test/features/contabilista/recados_do_contabilista_test.dart`.
- **Ordem de tabulação do portal** — o Tab desce a coluna em vez de atravessar
  a linha, passa pelo total do ano, salta rubricas sem total anual, abre o ano
  seguinte e larga o foco no fim. Provado com
  `supabase/functions/portal-contabilista/tabulacao_test.mjs` (`npm i jsdom`).
  **Por implantar** — a Edge Function em produção ainda tem a ordem antiga.
- **Link inválido** — verificado em primeira pessoa contra produção: 404 com
  "Este link já não é válido", e `POST` com token falso dá 401 e
  `{"erro":"link inválido"}`. Sem stack trace, sem inglês.

## Ler primeiro

- **`docs/OBJECTIVO_PUNHO.md`** — a fonte de verdade do produto. O que o Punho é, para quem, o conceito de diferenciação, os 17 princípios, a arquitectura, os indicadores, as balizas, o diagnóstico de hoje e o caminho. Substitui a leitura dispersa dos brainstorms e auditorias antigas.
- **`docs/FONTES_DAS_BALIZAS.md`** — investigação das referências para as balizas.

## O trabalho seguinte, por ordem

### 1. Correr o percurso no telemóvel real

Os testes acima fixam o layout; o aparelho é que decide o resto. Com o Redmi
ligado por USB: criar máquina com preço e valor de compra → criar cliente →
criar reserva que os use, tudo deitado com o teclado aberto. É o passo que
apanha o que nenhum teste de widget vê — o teclado do sistema, o MIUI, a
rotação a sério.

Do que ficou por provar aqui, só isto sobra:

- rodar a meio do preenchimento com o teclado do sistema aberto (nos testes é
  simulado, no aparelho é a `Activity` a ser recriada)
- o teclado que o Android abre mesmo em cada campo, agora que os tipos estão
  corrigidos

### 1b. As oito afirmações, e onde estão

**No Redmi deitado com o teclado aberto sobram 192,3 dp de altura para 761,6
de largura de corpo.** É a medida em que os testes correm.

| | Afirmação | Estado |
|---|---|---|
| 1 | Vê-se o que se está a escrever quando o teclado abre | fixado nos seis |
| 2 | O Guardar é sempre alcançável com o teclado aberto | fixado nos seis |
| 3 | Rodar a meio não perde o que já foi escrito | fixado; falta no aparelho |
| 4 | Zero overflow em paisagem com teclado | fixado; **rebentava na marcação** |
| 5 | A recusa aparece acima do teclado | fixado onde há validação |
| 6 | Voltar atrás pergunta antes de deitar fora | fixado nos seis |
| 7 | `1.250,00` grava 1250 | fixado ponta a ponta |
| 8 | Teclado certo em cada campo | fixado; **seis campos estavam errados** |

Sobre a 1: prova-se o que se **escreve**, não a moldura. Num campo de três
linhas ainda vazio, com o teclado a abrir, a caixa acaba 12,7 dp abaixo do
teclado — o `EditableText` põe o cursor à vista e pára aí, e à primeira tecla
o campo sobe inteiro. Foi medido com uma sonda antes de se decidir que não era
defeito. Endurecer o teste contra isso era exigir uma coisa que ninguém vive.

### 2. Portal do contabilista — testar em primeira pessoa no telemóvel

1. O botão do convite gera token válido, com período e validade certos
2. A mensagem sai inteira pelo canal (WhatsApp e copiar) — link não truncado, token não partido
3. O link aberto marca `aberto_em`
4. O que o contabilista grava aparece ao gestor na app
5. O recado dele aparece ao gestor no histórico — e some o realce depois de lido
6. ~~Link expirado dá erro decente~~ — feito, contra produção

Os passos 1, 2 e 4 são o caminho real do cliente.

### 3. Decisões do portal

- ~~**A mensagem do contabilista**~~ — decidida e feita: mostra-se ao gestor.
- ~~**A ordem de tabulação**~~ — decidida e feita: o Tab desce a coluna.
  **Falta implantar a Edge Function.**
- **O link com cara de Punho:** hoje mostra `supabase.co`. Decisão consciente (evita o token no `Location` de um redirect), a rever quando houver domínio próprio com proxy.

### 4. Depois

Recorrência das rubricas + fixo/variável explícito · consulta manual à Central de Balanços do Banco de Portugal para o CAE 773/77320 · prazo médio de recebimento e concentração de receita · ponto crítico e margem de segurança.

## Estado do repositório

Tudo **por committar**. `flutter analyze` limpo, **864 testes passam**.

| | |
|---|---|
| `D lib/data/repositories/dashboard_repository.dart` | Código morto: dados de demonstração sem consumidores |
| `D lib/domain/models/dashboard_summary.dart` | O modelo que o servia |
| `M lib/core/guidance/guidance_engine.dart` | O "até 35% de desconto" saiu do conselho e do pré-preenchimento da campanha |
| `M` ×5 `presentation/` | `isExpanded: true` nos 19 dropdowns que faltavam |
| `M workforce_pages`, `company_settings_page`, `finance_pages` | teclado com vírgula nos seis campos de dinheiro |
| `M` contabilista (domínio, serviço, providers, ecrã) | os recados passam a chegar ao gestor |
| `M supabase/functions/portal-contabilista/index.ts` | Tab desce a coluna — **por implantar** |
| `A test/features/formularios/redmi_deitado_test.dart` | 40 testes à medida do Redmi deitado |
| `A test/features/contabilista/recados_do_contabilista_test.dart` | 5 testes dos recados |
| `A supabase/functions/portal-contabilista/tabulacao_test.mjs` | 13 asserções da tabulação |

## Decisões de produto ainda em aberto

Leitura do mês é slide ou destino do rail · modelo de dados tipado, antes ou depois de mais indicadores · qual é a próxima vaga, camada de gestão ou fases do ciclo · facturação e núcleo fiscal partilhado com o WashInvoice · login, convite de colaborador e recuperação de conta.

## O passo que não é código

**Um empresário a sério à frente do ecrã.** É o de maior retorno da lista inteira, e o único que nenhuma sessão de trabalho produz sozinha.
