# Entrada de leads — landing page, WhatsApp e telefone

Direcção dada pelo Cesar a 31/07/2026: as leads devem poder **chegar de fora**,
não só ser escritas à mão dentro da app.

Este documento é desenho, não implementação. Nada disto está feito.

---

## Porque é que isto vale mais do que parece

Não é só poupar escrita. Uma lead que chega com a **origem** agarrada torna
calculável aquilo que hoje não é:

- **CAC por canal** — `publicidade do canal ÷ clientes novos vindos desse canal`.
  É o degrau 2 do refinamento progressivo já especificado em
  `LIGACAO_PERGUNTAS_SCREENS.md`, e sem origem na lead não há forma de lá chegar.
- **Que canal traz clientes que ficam**, e não só clientes que aparecem.
- **A conversão do slide 3 passa a ser por canal**, que é onde a alavanca
  Procura deixa de ser um número e passa a ser uma decisão.

O `Lead` já tem `source` (`LeadSource`), hoje com `call`, `referral`,
`facebook`, `google` e `other`. Falta acrescentar `landingPage` e `whatsapp`.

---

## O problema de arquitectura é o mesmo do botão "Recolhida"

Uma lead que chega de uma landing page nasce **no servidor**. A app sincroniza o
**estado operacional completo** com detecção de conflitos. Se o servidor
escrever leads e a app empurrar o estado todo, um dos dois perde.

É exactamente o problema do botão "Recolhida" do colaborador, e tem a mesma
solução:

**Uma tabela de entrada, só de acrescentar.**

```
punho_leads_entrada
  id · empresa_id · origem · nome · telefone · email
  mensagem · recebida_em · payload_bruto (jsonb)
  processada_em (null enquanto não for puxada para a app)
```

- Fontes externas fazem `insert`. Nunca tocam no estado operacional.
- A app lê o que ainda não processou, cria os `Lead` locais e marca
  `processada_em`.
- Append-only não colide: dois canais a escrever ao mesmo tempo sobrevivem os
  dois.
- `payload_bruto` guarda o que veio como veio. Quando um canal mudar de formato
  — e vai mudar — a informação não se perde por a app não a ter sabido ler.

**Isto e os eventos de entrega/recolha são a mesma peça de infra-estrutura.**
Vale a pena desenhá-las juntas: um canal de entrada no servidor que a app
consome, em vez de dois mecanismos parecidos feitos em alturas diferentes.

---

## Os três canais, por ordem de dificuldade real

### 1. Landing page — fácil, e é toda dele

Formulário em `decisaodigital.pt` → Edge Function → `insert`. Não depende de
aprovação de ninguém, não tem custo por mensagem, e o domínio já é dele.

Cuidados: um `insert` público precisa de protecção contra robôs (rate limit por
IP, honeypot ou captcha), senão a tabela enche-se de lixo e o KPI de conversão
afunda-se sozinho.

**É por aqui que se começa.** Prova a tabela de entrada e o consumo pela app
ponta a ponta, com o canal que não tem nenhum obstáculo externo.

### 2. WhatsApp — possível, mas não é um fim-de-semana

Sem rodeios sobre o que envolve:

- Exige **WhatsApp Business Platform** (Cloud API da Meta), com conta Business
  verificada, número dedicado — que deixa de poder ser usado na app normal do
  WhatsApp — e aprovação da Meta.
- Mensagens **iniciadas pela empresa** usam templates aprovados e são pagas.
  Responder dentro da janela aberta pelo cliente não é.
- A recepção é um webhook, que aponta para uma Edge Function e faz o `insert`.
  Essa parte é simples; o que demora é a verificação e a aprovação.

**Passo intermédio honesto, para não ficar parado:** um link `wa.me` na landing
page e no site com texto pré-preenchido. Não é integração — a lead continua a
ser escrita à mão — mas mede quantas conversas nascem por ali, o que diz se vale
a pena o trabalho todo antes de o fazer.

### 3. Contactos telefónicos — depende do que "telefone" quer dizer

São duas coisas diferentes e só uma é viável:

**(a) Importar os contactos do telemóvel** como leads. Permissão
`READ_CONTACTS`, justificável e aceite na Play Store. Resolve de caminho a
barreira de adopção já identificada na auditoria do primeiro empresário — o
empresário tem os clientes no telemóvel e desiste ao quarto escrito à mão.

**(b) Transformar chamadas recebidas/perdidas em leads.** Precisa de
`READ_CALL_LOG`, que a Google restringe a apps cuja função principal é
telefone/identificação de chamadas, com formulário de declaração. **Uma app de
gestão tem forte probabilidade de ser recusada** — e o risco não é só a
funcionalidade: é a app ser removida da loja.

Alternativa para (b) sem permissão nenhuma: **registo em dois toques**. O
empresário desliga a chamada e carrega num botão grande "Entrou uma chamada" que
abre a lead com o número já preenchido a partir da área de transferência ou
escrito à mão. Menos automático, zero risco de loja.

---

## Deduplicação — a parte que se esquece e estraga os números

A mesma pessoa liga, preenche o formulário e manda mensagem no WhatsApp. Três
leads, um cliente.

Sem deduplicação, **a conversão do slide 3 divide-se por três** e o CAC por
canal fica sem sentido. O KPI que acabou de ser ligado a dados reais passa a
mentir por excesso de entradas em vez de por constantes escritas à mão.

Regra proposta: **o telefone normalizado é a chave**. Uma entrada cujo telefone
já existe numa lead aberta não cria lead nova — acrescenta um contacto à que
existe, e a origem passa a ser uma lista em vez de um valor único. Assim a
atribuição continua a saber que ele veio primeiro pelo Google e depois pelo
WhatsApp, sem contar duas pessoas.

---

## Como recolher só as leads válidas — recomendação

A pergunta do Cesar: *como é que deve ser feita a colecta das leads válidas para
dentro da app?*

A resposta curta: **valida no servidor, aceita sem fricção o que é bom, segura o
duvidoso numa caixa de entrada, e nunca apagues nada.**

### 1. A validação é no servidor, nunca na app

A Edge Function é o único sítio que vê tudo o que chega. A app pode estar
fechada, sem rede, ou ser outra pessoa a olhar. Além disso, um endereço público
é uma porta aberta para a base de dados dele — a filtragem tem de estar do lado
que ele controla, antes de a linha existir.

### 2. Três destinos, não dois

Aceitar ou rejeitar é grosseiro de mais. O que funciona:

| Classificação | Critério | O que acontece |
|---|---|---|
| **Aceite** | Telefone válido · não duplica lead aberta · ritmo normal | Vira `Lead` directamente. Aparece no pipeline sem ninguém aprovar |
| **Retida** | Falta telefone · duplicado provável · rajada do mesmo IP · texto suspeito | Fica na caixa de entrada. Um toque aceita, um toque descarta |
| **Descartada** | Honeypot preenchido · submetido em menos de 2 s · sem contacto nenhum utilizável | Não aparece. Fica gravada na mesma |

**A maioria tem de cair em "Aceite".** Uma caixa de entrada que exige aprovar
tudo é só outro sítio para acumular trabalho — e a razão de existir isto é
poupar trabalho.

### 3. Nunca apagar. Rejeitar é classificar

Tudo aterra em `punho_leads_entrada` com o `payload_bruto` intacto, incluindo o
que foi descartado. Sem isso não se distingue **"a campanha não trouxe nada"** de
**"a campanha trouxe lixo que nós apagámos"** — e essa diferença decide se se
volta a pagar por aquele canal.

### 4. Normalizar o telefone é a peça que sustenta tudo

`+351 912 345 678`, `912345678` e `912 345 678` são a mesma pessoa. Guardar em
**E.164** no momento da entrada, e guardar o original ao lado.

Sem isto a deduplicação não funciona; sem deduplicação a conversão do slide 3
divide-se pelo número de canais. **É o passo mais barato com maior efeito nos
números.**

Um telefone que não normaliza é sinal forte de lixo — é o melhor critério de
"válida" que há, e é mais fiável do que qualquer análise do texto.

### 5. Contra robôs, antes de captcha

Por ordem de custo para quem preenche a sério:

1. **Honeypot** — campo escondido que só um robô preenche. Zero fricção.
2. **Tempo até submeter** — menos de 2 segundos não é uma pessoa.
3. **Limite por IP** — cinco submissões por hora chega e sobra.
4. **Captcha** — só se os três primeiros não bastarem. Custa conversões reais.

### 6. Uma lead que chega e ninguém vê é pior do que não existir

Duas saídas, e as duas já existem no projecto:

- **Notificação push** — a Edge Function `enviar-push` já está montada e a
  funcionar para o Punho.
- **Tarefas** — o `tarefas_service` já gera trabalho por fazer a partir do
  estado. Uma lead por contactar é exactamente isso.

### 7. O número que interessa medir é o tempo até ao primeiro contacto

Não é quantas leads entram. É quanto tempo passa até alguém responder — é isso
que converte.

E a app já tem as peças: `leadsPorContactar` devolve-as ordenadas pela mais
antiga, e a célula do slide 3 já mostra *"N sem contacto há mais de 5 dias"*.
Com a origem agarrada, isso passa a ser **por canal**: se as leads do WhatsApp
esperam duas horas e as da landing page dois dias, o problema não é o canal, é o
hábito — e essa é uma recomendação que a app pode dar.

### Em resumo

O caminho de uma lead válida, do início ao fim:

```
landing page / WhatsApp / agenda
        ↓  (Edge Function: normaliza · valida · classifica)
punho_leads_entrada  ← payload_bruto guardado sempre
        ↓  aceite                    ↓  retida
   Lead no pipeline            caixa de entrada (1 toque)
        ↓
  push + tarefa "contactar"
        ↓
  mede tempo até ao 1º contacto → alavanca Procura
```

---

## Ordem sugerida

1. **Tabela de entrada + consumo pela app** — a peça comum a tudo o resto.
2. **Landing page** — o canal sem obstáculos, que prova a peça.
3. **Deduplicação por telefone** — antes de haver dois canais, não depois.
4. **Importar contactos** — grande ganho de adopção, permissão fácil.
5. **`wa.me` medido** — decide se o WhatsApp a sério compensa.
6. **WhatsApp Cloud API** — só quando os números disserem que vale.

---

## Por decidir com o Cesar

- **"Contactos telefónicos"** é importar a agenda (a) ou apanhar chamadas (b)?
  Muda tudo: (a) faz-se, (b) arrisca a presença na loja.
- Uma lead que chega de fora entra **directamente na lista**, ou numa caixa de
  entrada que ele aprova antes? Com landing page pública, a segunda protege
  contra lixo.
