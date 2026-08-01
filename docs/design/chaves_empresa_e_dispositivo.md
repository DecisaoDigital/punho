# Chaves de empresa e de dispositivo — desenho

> Estado: **desenho para aprovação**. Nada disto está implementado. Escrito a
> 1 ago 2026 a partir das regras que o Cesar fixou em conversa.

## O modelo, em duas linhas

Cada empresa tem **uma chave mestre**, criada pelo primeiro dispositivo que lá
entra. Cada aparelho tem a **sua própria chave**, e vive pendurado na mestre. O
par `mestre + dispositivo` é o que identifica um posto de trabalho.

```
TRD3434567654                     ← chave mestre (empresa, ligada ao NIF)
TRD3434567654 + note10pro987432   ← o telemóvel do funcionário
TRD3434567654 + tabletA1122334    ← o tablet do mesmo funcionário
```

## Vocabulário

| termo | o que é | exemplo |
|---|---|---|
| **chave mestre** | a empresa e o seu plano. Nasce com o primeiro dispositivo, fica ligada ao NIF | `TRD3434567654`, `CD-POS23238974` |
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

## O que fica por decidir

1. **Quando um colaborador sai**, a chave do aparelho **morre ou hiberna**?
   Morrer é limpo; hibernar poupa trabalho a quem volta (sazonais, baixas).
2. **O `licenca.json` local do POS passa a levar as duas chaves?** Sem isso, o
   POS offline não sabe validar o par — e o POS trabalha offline por desenho.
3. **Uma empresa que declare mais colaboradores do que o plano dá** — a
   Terraforte declara 4 com 3 vagas. Recusa-se o quarto convite, avisa-se o
   empresário, ou propõe-se subir de plano? É uma oportunidade de venda que
   hoje se perde em silêncio.
