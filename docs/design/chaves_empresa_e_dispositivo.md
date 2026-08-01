# Chaves de empresa e de dispositivo — desenho

> Estado: **implementado** a 1 ago 2026, no mesmo dia em que foi escrito e
> decidido. Escrito a partir das regras que o Cesar fixou em conversa; as cinco
> questões em aberto foram decididas e a cadeia toda foi aplicada — ver
> "O que já está feito" no fim.

## O modelo, em duas linhas

Cada empresa tem **uma chave mestre**, que nasce na **primeira associação de um
dispositivo** — é esse primeiro aparelho que junta email e contribuinte e forma
a conta principal da empresa. Cada aparelho tem a **sua própria chave**, e vive
pendurado na mestre. O par `mestre + dispositivo` é o que identifica um posto de
trabalho.

```
TRD3434567654                     ← chave mestre (empresa, ligada ao NIF)
TRD3434567654 + note10pro987432   ← o telemóvel do funcionário
TRD3434567654 + tabletA1122334    ← o tablet do mesmo funcionário
```

### Nasce **com** o primeiro dispositivo, não é feita **dele**

A distinção importa e vale a pena ficar escrita. O primeiro aparelho é o
**momento** em que a mestre nasce — não a sua **matéria-prima**. O valor é novo
e opaco (um UUID, ou um código curto legível para ser lido ao telefone), sem
nada dentro que venha daquela máquina.

A razão é uma só: a mestre é a chave que tem de **sobreviver a todos os
aparelhos**. O empresário troca de telemóvel, o POS é substituído, o PC morre —
e a empresa continua a mesma. Se a mestre fosse derivada do primeiro aparelho,
perdia sentido no dia em que esse aparelho desaparecesse, que é o dia em que
mais se precisa dela.

O prefixo legível (`TRD`, `POSII`) é a exceção admitida: vem do nome do
aparelho, mas é decoração para tu reconheceres a linha, não identidade.

## Vocabulário

| termo | o que é | exemplo |
|---|---|---|
| **chave mestre** | a empresa e o seu plano. Nasce na primeira associação de um dispositivo, fica ligada ao NIF | `TRD3434567654`, `CD-POS23238974` |
| **chave de dispositivo** | um aparelho concreto. Nasce quando esse aparelho é associado | `note10pro987432`, `POSII64846545` |
| **par** | mestre + dispositivo. É o que identifica quem está a trabalhar e onde | `TRD3434567654+note10pro987432` |

O prefixo legível (`TRD`, `POSII`) vem do nome do aparelho — serve para tu o
reconheceres na lista, não tem significado técnico.

## Punho — o titular do par é o **email**

O Punho tem contas pessoais: cada pessoa entra com o seu email, e o par diz a
que empresa pertence e com que cargo.

**1. O empresário cria a conta.** É sempre o primeiro. Nasce a chave mestre com
o NIF dele, e o aparelho onde a criou recebe a primeira chave de dispositivo.

**2. O empresário noutro aparelho.** Entra com o mesmo email no portátil, no
tablet ou no telemóvel. É reconhecido, o aparelho ganha chave própria, e fica
pendurado na mesma mestre. Nunca lhe é pedido o NIF outra vez.

**3. Colaborador com convite.** O convite já leva a chave mestre. Ao criar o
perfil, gera-se a chave do aparelho e o par fica colado ao email dele — para
sempre. A app sabe daí em diante que aquele email vale aquela empresa e aquele
cargo.

**4. Colaborador sem convite.** Inscreve-se com nome e um NIF que já existe.
Fica à espera de aprovação (hoje tua, no futuro do empresário por notificação).
Aprovado, recebe na hora a associação `mestre + chave nova`.

### O limite conta emails, não aparelhos

Uma empresa são **1 empresário + 3 colaboradores** por omissão — quatro emails
distintos. O limite vive em `punho_subscricoes.limite_colaboradores_ativos` e é
uma alavanca manual: sobe se o cliente pagar mais.

Um colaborador com telemóvel **e** tablet ocupa **uma** vaga. **O dispositivo
nunca é facturável** — serve para identidade e para travar partilha de conta.

### Sessão exclusiva

Um colaborador pode ter vários aparelhos registados, mas **não os pode usar ao
mesmo tempo**. Sem esta regra, três vagas dariam para seis pessoas.

**Regra: o último a entrar ganha.** Quem entra no tablet expulsa a sessão do
telemóvel, que passa a pedir login. É o que o utilizador honesto espera ao
trocar de aparelho, resolve sozinho o caso do telemóvel perdido, e torna a
partilha inútil na prática — dois a partilhar a conta andam a expulsar-se um ao
outro o dia todo.

### O empresário tem direito a duas

O dono pode ter **duas sessões ao mesmo tempo** — o caso real é o telemóvel na
mão e o PC do escritório sempre aberto. À terceira, aplica-se-lhe a mesma regra:
a mais antiga cai.

Os colaboradores continuam com **uma**. É onde está o risco de partilha, e é aí
que a regra tem de apertar.

## POS — o titular do par é o **dispositivo**

O POS não tem contas pessoais: nunca autentica, corre sempre com a chave
anónima. O email é o do dono e é sempre o mesmo, por isso **não distingue nada**
— quem distingue é o aparelho.

```
cd_mendes@hotmail.com · NIF 515307548
  CD-POS23238974                      ← primeiro terminal, chave mestre
  CD-POS23238974 + POSII64846545      ← segundo terminal
```

O segundo terminal recebe chave própria e fica associado à mesma mestre. As
regras de plano e de limite são as mesmas; muda só o que se conta.

**Cada terminal adicional é cobrado à parte.** No POS o que se vende é o posto:
o primeiro vem com a licença, os seguintes pagam. É o equivalente ao colaborador
extra do Punho — muda só a unidade, porque muda quem é o titular do par.

Os 3 terminais POS que existem hoje são **de teste**. Não há migração a fazer.

## O que existe hoje, e o que falta

### Já existe e serve

- `punho_membros` — liga email → empresa → perfil. É metade do par.
- `punho_convites` e o fluxo de pedido/aprovação — os caminhos 3 e 4 já andam.
- `punho_subscricoes.limite_colaboradores_ativos` — a alavanca do plano.
- `punho_instalacoes` — tem `empresa_id` e um `dados` jsonb. **Está vazia de
  conteúdo** (só `{"origem":"aprovacao-control"}`). É o sítio natural para as
  chaves de dispositivo, e já foi pensado para isso.

### Falta

- **A chave mestre não existe como conceito.** Hoje há `licencas.machine_id`,
  que é o hash de *um* aparelho, e nada que represente a empresa.
- **A chave de dispositivo não se liga a ninguém.** O `machine_id` do Punho vive
  isolado em `licencas`, sem empresa e sem email.
- **Nada impede duas sessões** do mesmo colaborador.

### O que está a produzir os duplicados de hoje

Há **duas fontes** a criar licenças `punho`, e não se conhecem:

| fonte | chave que usa | NIF |
|---|---|---|
| trigger `punho_empresas_sync_licenca` | `punho:<empresa_id>` | real |
| Edge Function `registar-terminal` | hash do aparelho | `000000000` |

No modelo novo isto resolve-se sozinho: a **mestre** é a licença (uma por
empresa, NIF real) e os **dispositivos** deixam de criar licenças — passam a ser
linhas em `punho_instalacoes`.

## Ordem de implementação proposta

1. **Chave mestre.** Nasce no registo do empresário, guardada na licença da
   empresa. Sem isto nada do resto tem onde se pendurar.
2. **Chaves de dispositivo em `punho_instalacoes`**, com `empresa_id`, o
   `machine_id` do aparelho e o email a que pertence.
3. **`registar-terminal` deixa de criar licença para o Punho** quando o
   utilizador já pertence a uma empresa — regista o dispositivo em vez disso.
   *(É a alteração que toca na função partilhada com o POS: mexer só dentro do
   ramo `punho`, guardar a versão actual e confirmar logo a seguir que um
   registo `pos` continua a responder.)*
4. **Sessão exclusiva** — o último a entrar ganha.
5. **POS**: mesma estrutura, titular do par é o dispositivo.

Os passos 1 e 2 não mexem no POS e podem ser feitos com segurança. O passo 3 é o
único que exige o cuidado descrito.

## Porque é que isto interessa ao negócio

Palavras do Cesar: **é o Punho que lhe vai dar este controlo**. O modelo nasce
aqui — chave da empresa, aparelhos pendurados, limite por email — e depois
aplica-se ao POS, que hoje não tem forma de saber quantos postos uma empresa
está mesmo a usar. Sem isto, acrescentar um terminal ou uma pessoa não se vê e
não se cobra.

## Decidido

| questão | decisão |
|---|---|
| sessões simultâneas do empresário | **duas** (telemóvel + PC do escritório). À terceira, cai a mais antiga |
| sessões dos colaboradores | **uma**. É aí que está o risco de partilha |
| terminal POS adicional | **cobrado à parte** |
| colaborador adicional no Punho | **cobrado à parte** (limite manual por empresa) |
| dispositivo | **nunca facturável** — serve para identidade e para travar partilha |
| os 3 terminais POS actuais | são de teste, **não há migração** |
| colaborador que sai | o **empresário elimina o email**. É o que liberta a vaga |

### Sair da empresa

Quando um trabalhador sai, **o empresário elimina o email**. É essa acção que
liberta a vaga — não há hibernação nem limpeza automática. Enquanto o email lá
estiver, continua a ocupar lugar, mesmo que ninguém entre há meses.

É a leitura certa: a vaga foi paga por ele, e é ele que decide quando a
reaproveita. Se o trabalhador voltar mais tarde, entra por convite novo e recebe
chaves novas — o histórico não se recupera nem faz falta.

**Ao eliminar o email caem também as chaves dos aparelhos dele.** É o que fecha
a porta: sem par válido, nenhum daqueles dispositivos volta a entrar.

Duas coisas que isto obriga a ter, e vale a pena assinalar porque uma já existe:

- **Um sítio onde o empresário elimina.** Hoje há "Eliminar colaborador" na
  lista de Colaboradores, com 6 segundos para anular — mas essa acção arquiva a
  *ficha* na app. Tem de passar a cortar também o **acesso**, senão a vaga não
  se liberta e o ex-colaborador continua a entrar.
- **O que acontece ao trabalho que ele deixou.** Não se apaga. As reservas
  guardam `collaboratorNameSnapshot`, precisamente para o nome continuar a
  ler-se depois de a ficha desaparecer — já foi pensado, e serve aqui.

E do lado de quem foi eliminado, o ecrã já existe: `AcessoIndisponivelScreen`,
que é o que o `decidirAcesso` mostra quando o estado é `revogado`.

## O `licenca.json` já é por terminal

Levantei isto como risco — «e se copiarem o ficheiro para outro PC?» — e estava
errado. O ficheiro que o Control emite **já leva o `machine_id`**, ao lado do
NIF e da validade, e faz parte do que é assinado:

```json
{ "nif": "...", "nome": "...", "machine_id": "...", "plano": "...",
  "validade": "...", "assinatura": "..." }
```

Copiá-lo para outro PC não serve: o `machine_id` não bate com o da máquina, e a
assinatura não se refaz sem a chave. **A porta já estava fechada.**

Para o par `mestre + dispositivo`, isto até simplifica: o `machine_id` que já lá
está **é** a chave do dispositivo. Falta acrescentar-lhe a chave mestre — uma
linha no JSON, e a estrutura aguenta.

### Decidido: o ficheiro passa a levar as duas chaves

```json
{ "nif": "...", "nome": "...",
  "chave_mestre": "TRD3434567654",     ← linha nova
  "machine_id": "...",                  ← já existia: a chave do dispositivo
  "plano": "...", "validade": "...", "assinatura": "..." }
```

A razão é o offline. O POS valida pelo ficheiro local, sem falar com o
servidor: se a mestre não viajar lá dentro, o terminal sabe que **é ele**, mas
não sabe **de que empresa é** — e o par, que é a unidade do modelo todo, nunca
chega a ser verificável no sítio onde tem de ser.

Com a linha lá, o arranque compara as duas: o `machine_id` contra o que a
máquina calcula de si própria, a `chave_mestre` contra a que está guardada na
instalação. Falha uma, não arranca.

A `chave_mestre` entra dentro do que é assinado, como tudo o resto — senão
edita-se o ficheiro num editor de texto e o par vale zero.

**Isto não resolve** a chave de assinatura viver dentro do binário do POS (ver
acima). São problemas diferentes; este fecha a cópia entre máquinas, aquele
só se fecha tirando a assinatura do cliente.

Fica de pé o que o próprio contrato das duas apps já assinala, e que é outro
problema: a chave que assina este ficheiro vive **dentro do binário do POS**.
Quem extrair o executável consegue fabricar licenças válidas. Não se resolve com
o par; resolve-se tirando a assinatura do cliente (Edge Function).

## A chave de dispositivo já existe — e nas duas apps

Lido no código, não deduzido. O POS (`DecisaoDigital/WashFactura`,
`lib/services/licenca/licenca_service.dart`) calcula o `machine_id` **na
própria máquina**:

```
SHA-256 de:  hostname | versão do SO | MachineGuid do registo | serial da motherboard
```

Três coisas que vale a pena reter do que lá está:

- **O serial da motherboard não é enfeite.** O comentário no código diz ao que
  vem: evitar colisões entre PCs com Windows clonado da mesma imagem. Sem ele,
  duas máquinas clonadas partilhavam o MachineGuid e davam o **mesmo**
  `machine_id` — exatamente o cenário de quem quer dois postos pagando um.
- **Degrada com cuidado.** Se o `reg` falhar, usa só hostname + SO; se o `wmic`
  não existir (Windows recente), tenta PowerShell. Nunca rebenta — mas quanto
  menos fontes entram no hash, mais fraco o identificador fica.
- **Fica em cache**, como no Punho.

O Punho faz o mesmo com outra semente (`lib/core/licenca/machine_id.dart`):
Android → SHA-256 de `android:<ANDROID_ID>`; Windows → SHA-256 de
`windows:<nome do PC>:<MachineGuid>`. Mesma forma nas duas apps: 64 hex.

**O Control nunca gera nenhum destes valores** — recebe-os da app e copia-os
para o `licenca.json`. Portanto a chave de dispositivo do modelo **já existe e
já funciona**. O que falta é só a chave mestre, que não existe em lado nenhum.

## Crescer acima do plano

O empresário envia convite para mais um ou dois colaboradores. Esses convites
**não passam automaticamente**: entram em avaliação do Cesar.

Isso é deliberado, e não é burocracia — é o momento da conversa. Dá tempo de
falar com o empresário e perceber o que ele quer:

- **retirar um email** que já lá não faz falta, e usar a vaga que se liberta; ou
- **aumentar o plano**, e aí são-lhe ditos os custos

Se aceitar, o Cesar valida os emails e **envia a factura**.

O convite acima do limite é, portanto, um **sinal de venda** — não um erro a
bloquear em silêncio. É o que justifica o passo manual: se a app recusasse
sozinha, a conversa nunca acontecia e a receita perdia-se sem ninguém dar por
ela.

## O que já está feito

Aplicado a 1 ago 2026. Nada disto muda as licenças que já estão instaladas: sem
chave mestre, tudo assina e valida exactamente como antes.

**Base de dados** (aplicada em produção; `washinvoice-control/supabase/chaves_mestre.sql`)
- tabela `chaves_mestre`, uma linha por NIF, escrita só por `service_role`
- `obter_ou_criar_chave_mestre()` — idempotente. É o que faz o segundo terminal
  do mesmo NIF entrar na empresa que já existe em vez de fundar outra
- `gerar_chave_mestre()` — valor novo e opaco, alfabeto sem `0/O/1/I/L` para se
  poder ler ao telefone. O prefixo vem do nome da máquina e é só decoração
- coluna `licencas.chave_mestre`, `NULL` nas licenças anteriores

**Control**
- `atribuir_chave_mestre` na Edge Function `gerir-licenca` — único caminho para
  a obter, auditado como qualquer outra mutação
- gerar a licença passa a pedir a chave **antes** de assinar, no mesmo gesto
- linha "Chave mestre" no detalhe da instalação, com botão de copiar

**POS** (`DecisaoDigital/WashFactura`, ramo `chave-mestre-do-par`)
- camada **2b** em `avaliarLicenca`: recusa uma licença de outra empresa mesmo
  antes de o NIF estar configurado — que é o buraco que a 4ª camada deixava
- a chave fixa-se na primeira licença válida que a traga e nunca é substituída
- a CLI de emissão **pergunta** a chave em vez de a inventar

**Punho**
- `LicencaInfo.chaveMestre`, vinda do `validar-licenca` — o Punho não tem
  `licenca.json` assinado, é por aqui que sabe a que empresa pertence

### O que continua por fazer

- **tirar a chave de assinatura de dentro do binário do POS** (Edge Function).
  É o buraco maior e é independente de tudo isto: o par fecha a cópia entre
  máquinas, não fecha quem extrai o executável e fabrica licenças.
