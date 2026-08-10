# Hardening — índice das fases

**Não confundir com `PLANO_DO_CICLO.md`.** Aquele numera fases de **produto**
(Fase 0 a 4: espinha, orçamento, execução, cobrança, a volta). Este numera fases
de **hardening**, e os números repetem-se sem terem nada a ver um com o outro.
Quando alguém disser «Fase 5», perguntar de qual.

E dentro de uma fase de hardening há **passos**. «Passo 5 da Fase 3» é a
renomeação dos canais de sincronização; «Fase 5» é visibilidade. Já se
confundiram uma vez.

Cada fase corre numa sessão dedicada e fecha com `docs/HANDOVER_<fase>.md` —
regra em `AGENTS.md`, secção «Uma sessão por fase».

---

## Onde estamos

| Fase | O quê | Estado |
|---|---|---|
| **1** | Parar a hemorragia | **1.2 feito** (23P01 → balde visível, opção C). 1.1 e 1.3 mexem na base viva e esperam autorização. |
| **1.2-bis** | A quarentena guarda a frase do servidor | feito — e é o que torna a Fase 5 possível |
| **2** | Autorização por campo, aplicada à base viva | feito. Matriz, provas, e o 42501 que tranca as apps antigas |
| **C** | Consolidação — três linhas de trabalho por committar | feito, `v0.3.5`. `docs/HANDOVER_FASE_C.md` |
| **C3** | As funções deixam de nascer abertas | feito. `docs/HANDOVER_C3.md` |
| **3** | Um só motor de sincronização | **em curso.** `docs/HANDOVER_FASE_3_PARCIAL.md` |
| **5** | Visibilidade | por fazer |
| **6** | Cifra local | por fazer |
| **7** | Realtime, docs, gate de release | por fazer |

**Não há Fase 4 nesta lista.** Ou nunca existiu, ou tem outro nome — não a
inventar. Perguntar antes de assumir que falta alguma coisa entre a 3 e a 5.

---

## Fase 5 — visibilidade

Mostrar ao gestor o que a app anda a fazer por baixo, em vez de o deixar a
adivinhar:

- **estado da sincronização** — o `InfoSync` já existe e ninguém o lê;
- **quarentena** — e agora com a **frase do servidor**, graças à 1.2-bis. Sem
  ela, um item em quarentena dizia «falhou» e mais nada;
- **conflitos** — o balde de conflitos de reserva. **Continua vazio de
  propósito**: a infra existe desde a Fase 0, e não se semeia um balde para ele
  ter aspecto de cheio;
- **o tecto do C2**.

## Fase 6 — cifra local

**Inclui a fila e a quarentena, não só o repositório.** É o ponto todo: cifrar
o `punho.operations.v1` e deixar de fora o `RegistoDeOperacoes` era cifrar a
casa e deixar a chave na porta — a fila tem os mesmos payloads, com os mesmos
nomes, moradas e valores.

## Fase 7 — realtime, docs, gate de release

---

## Adiado, com a razão

- **Código de erro próprio para o conflito de reserva.** Hoje é `23P01`, que é
  o `exclusion_violation` genérico do Postgres. Um código próprio só depois de
  **o terreno estar no cliente novo**: tolerância no cliente primeiro,
  especificidade no servidor depois. Ao contrário, cada telemóvel que ainda não
  actualizou passa a receber um código que não sabe ler.
- **As políticas com `roles = {public}`** — são a causa das cinco funções que
  ficam executáveis por `anon` depois da C3. Passá-las a `to authenticated`
  fecha-as, mas mexe em políticas e exige o smoke de isolamento por cima.
  Tarefa própria. Ver `docs/HANDOVER_C3.md`.
- **`punho_meu_estado_acesso`** sai da lista aprovada quando não houver APKs
  antigos instalados.
