# Cifra local — o que falta e quanto custa

**Estado a 8 de Agosto de 2026.** Decisão documentada, não implementada.

## O que já ficou fechado

`android:allowBackup="false"` e `res/xml/regras_de_extraccao.xml` no manifesto.
Isso impede o sistema operativo de **distribuir** os ficheiros da app — para o
Google Drive pessoal e para o telemóvel seguinte numa troca de aparelho.

Não é cifra. Os dados continuam em claro no aparelho.

## O que continua aberto

`lib/data/repositories/operation_repository.dart` guarda tudo em
`SharedPreferences`, como JSON em texto simples: clientes com nome, telefone e
NIF, fichas fiscais com IBAN e NISS, despesas, leads.

Em `/data/data/pt.decisaodigital.punho/shared_prefs/`. Num telemóvel sem root e
com o ecrã bloqueado, o sandbox do Android chega para o dia-a-dia. Não chega
para: aparelho com root, aparelho perdido sem cadeado de ecrã, extracção
forense, ou uma cópia feita por um gestor de ficheiros com privilégios.

O cadeado da app **não** está exposto: o PIN é um `sha256` com salt guardado em
`flutter_secure_storage` (`lib/core/cadeado/cadeado_service.dart:15`), que no
Android é `EncryptedSharedPreferences` com a chave no Android Keystore. É
precisamente o modelo que falta aos dados de negócio.

## As três saídas, e a que se recomenda

**A — passar tudo para `flutter_secure_storage`.** Barato de escrever, caro a
correr: cifra entrada a entrada, e aqui gravam-se blocos JSON inteiros a cada
alteração. Degrada com o crescimento dos dados, que é exactamente quando importa.
Descartada.

**B — SQLite cifrado (SQLCipher), chave no Keystore.** É a solução a sério:
cifra em repouso, leituras parciais, consultas. Mas obriga a trocar o modelo de
persistência inteiro — de "um JSON por colecção em prefs" para SQL —, a escrever
a migração dos dados de quem já tem a app instalada, e a rever tudo o que hoje
assume leitura síncrona em memória. É um sprint, não um serão, e toca em código
que está estável.

**C — cifrar o payload, mantendo `SharedPreferences` (recomendada).** Uma camada
de `encode`/`decode` com AES-GCM à entrada e à saída do repositório: chave
aleatória de 256 bits gerada na primeira execução, guardada em
`flutter_secure_storage` — ou seja, no Keystore — e nunca escrita em disco pela
app. O resto do código não muda: continua a receber os mesmos objectos.

Custo: uma tarde. O trabalho real não é cifrar, é o resto —

- **migração dos dados existentes**: ler em claro uma última vez, regravar
  cifrado, e uma marca de versão no formato para isto não correr duas vezes;
- **o que fazer quando a chave desaparece**. O Keystore perde as chaves ao
  mudar o bloqueio de ecrã em alguns fabricantes, e perde-as sempre num
  *factory reset*. Sem chave, os dados locais são lixo. A app tem de saber
  reconhecer isso, limpar, e ressincronizar do Supabase em vez de ficar num
  ecrã partido — o que só é seguro porque **o que vale está no servidor e o que
  está no aparelho é cache**. Esta é a razão pela qual a opção C é aceitável;
- **testes**: um que prove que o disco não contém o NIF em texto simples, e
  outro que prove que a app recupera de uma chave em falta.

## Recomendação

Fazer a **C** quando entrar o primeiro cliente que não seja o piloto, ou antes
disso se algum questionário de segurança perguntar por cifra em repouso —
responder "não" a essa pergunta é pior do que o custo de a implementar.

Até lá, o `allowBackup="false"` já tira o cenário mais provável do mapa: os
dados a saírem sozinhos do telemóvel sem ninguém ter feito nada.
