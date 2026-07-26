# v0.0.4 — Definições da Empresa, e o fim dos números fantasma

Branch: `feat/definicoes-empresa`, a partir do topo da v0.0.3.

Duas queixas do Cesar, com a mesma raiz emocional ("isto não é meu"):

1. **"Escrevi para o vazio."** O onboarding recolhe 16 campos — responsável,
   empresa, forma jurídica, NIF, contactos, morada, colaboradores, veículos,
   máquinas, facturação, manutenção, custos fixos — e nenhum deles voltava a
   aparecer em sítio nenhum. Não havia como confirmar, e muito menos corrigir.
2. **"Vi números que não eram meus."** No painel de gestão.

## 1. O ecrã

`lib/features/company/presentation/company_settings_page.dart`

Formulário em quatro secções (`_CardSeccao`, ícone + título): Identificação,
Contactos e morada, Equipa e frota, Referências financeiras. Mais uma quinta,
"Repor", explicada abaixo. Botões **Guardar** e **Cancelar** no fim. Sem
`autofocus`: quem abre isto vai a um campo específico, não ao primeiro.

Só o gestor entra. Com Supabase ligado, quem chega à `AppShell` já é gestor
aprovado — decide o `AcessoGate`. Sem Supabase manda o perfil da sessão de
demonstração. A página verifica outra vez por si (`_podeEditar`), porque é
navegável directamente e uma página não deve depender de quem a abriu.

## 2. Acesso: opção B (botão no painel), não destino na barra

Escolhida a **B** do prompt: um `IconButton(Icons.edit_note)` no cabeçalho do
painel de gestão, com tooltip "Editar dados da empresa".

Porquê, além do argumento dos 72 dp da barra lateral: os dados da empresa
visitam-se **uma vez por mês, se tanto**. A barra é para os sítios onde se
trabalha todos os dias (máquinas, clientes, reservas). Um destino permanente
para isto competiria por espaço com o trabalho real, e a barra é o recurso mais
escasso do ecrã em telemóvel.

Há também uma razão de coordenação: a barra lateral e a `AppShell` estão a ser
mexidas noutra frente (captura de comprovativos). O painel não, portanto o botão
entra sem colidir.

## 3. `updateCompanySettings` e o problema de apagar

`lib/core/operations/operations_controller.dart`

Método novo, separado do `completeOnboarding`: aquele **define** o onboarding e
marca a app como configurada, este só **altera** o que recebe. Sem onboarding
não faz nada — sem empresa não há o que editar, e inventar uma aqui saltava o
fluxo de arranque.

### Porque não bastava `String?`

A regra 4 diz que limpar o NIF tem de funcionar. Com parâmetros `String?` e a
convenção habitual "`null` preserva", **apagar era impossível**: `null` já
significava "não mexer". É o mesmo defeito registado no P2-5 da auditoria
v0.0.3, em que limpar a diária de uma máquina não a limpava.

Daí o `Campo<T>`:

```dart
updateCompanySettings(companyTaxId: const Campo(null));   // apaga
updateCompanySettings(companyPhone: const Campo('913…')); // escreve
updateCompanySettings(companyName: 'Nova');               // não mexe no NIF
```

Não passar o parâmetro preserva; passar um `Campo` manda o valor, `null`
incluído. Por isso o novo `OnboardingData` é construído campo a campo em vez de
por `copyWith` — o `copyWith` usa `?? this` e nunca conseguiria apagar nada. O
`OperationsState` tem a mesma limitação, daí o `_comDadosDaEmpresa`.

Excepção: `companyName` e `legalForm` são obrigatórios no modelo. Nome em branco
mantém o anterior em vez de deixar a empresa sem nome.

### `hasFleet` deriva dos veículos

`OnboardingData` ganhou `declaredVehicleCount`. Antes só existia o booleano
`hasFleet`, e o número que o utilizador escrevia no onboarding perdia-se — o
ecrã de Definições não tinha o que mostrar de volta. Agora guarda-se o número e
`hasFleet` é `> 0`.

Consequências verificadas em teste: zero veículos tira a área de Frota da
navegação, zero colaboradores tira a de Funcionários, e voltar a pôr um traz a
área de volta.

`completeOnboarding` ganhou `declaredVehicleCount` **opcional** (`0` por
omissão), portanto quem já o chama só com `hasFleet` continua a compilar. O
onboarding em curso noutra frente já recolhe o número (`vehicles`) e calcula
`hasFleet: vehicles > 0`; falta-lhe passar `declaredVehicleCount: vehicles` para
o número sobreviver — **é o único ponto de ligação que fica pendente**, e até lá
o ecrã de Definições mostra 0 veículos a quem acabou de fazer onboarding com
frota. Editar e guardar corrige.

### `CompanySettings` (o modelo antigo)

Não foi fundido, e é de propósito. O `CompanySettings` de
`lib/domain/models/company_settings.dart` tem dois campos (`hasFleet`,
`activeCollaboratorLimit`) e é servido por um repositório de demonstração com
valores fixos (`hasFleet: true, activeCollaboratorLimit: 5`). Está morto no
caminho real: a `AppShell` usa `visibleOperationalDestinations(OperationsState)`,
não `visibleDestinations(CompanySettings)`. Fundir implicava mexer no
`navigation_controller` e no teste que o cobre, sem nada a ganhar para o
utilizador. Fica registado como código a remover quando o modo de demonstração
sair — não é uma segunda fonte de verdade dos dados da empresa, porque **não é
lida por nada que o utilizador veja**.

## 4. Os números fantasma: encontrados

Não era `HistoricalMonth` residual nem defaults em widgets. Era herança:

```dart
class PersistentOperationRepository extends LocalDemoOperationRepository
```

O `LocalDemoOperationRepository` inicializa os campos com **dados de
demonstração**: duas máquinas (`Mini escavadora 1.8T` a 185,00 €/dia e
`Plataforma elevatória`, parada) e um cliente (`Construções Silva`,
912 000 000). O repositório persistente herda-os. E o `_restore()`, quando não
encontrava nada guardado, **saía sem tocar em nada** — o comentário original
dizia mesmo "não impede a app de iniciar com os dados demo".

Resultado num telemóvel acabado de instalar, ou depois de *Clear data*: o painel
mostrava "Máquinas identificadas 2", "Máquinas disponíveis 1", "Máquinas
paradas 1", e a lista de clientes tinha uma empresa que ninguém criou. Se o
gestor declarou 5 máquinas no onboarding, ainda por cima as contas de "faltam
identificar" saíam erradas.

### O que mudou

- `_restore()` esvazia a memória **antes** de aplicar o que estiver guardado. Um
  dispositivo real nasce vazio.
- Cache corrompida também arranca vazia, em vez de meio estado antigo.
- `LocalDemoOperationRepository` continua com os dados de demonstração: é o
  repositório do modo local e os testes assentam neles (`m1`, `m2`, `c1`).

### Porque também era preciso um botão de repor

O arranque vazio só resolve para quem instala de novo. Quem já tem a app
instalada tem os dados de demonstração **dentro do armazenamento local**: à
primeira gravação de qualquer coisa, o `_persist()` escreveu o payload completo,
demonstração incluída. Nascer vazio não os apaga.

Daí o **"Repor dados desta app"** na secção final das Definições, com diálogo de
confirmação: apaga tudo neste dispositivo (`OperationRepository.resetAll()`,
incluindo a chave em `SharedPreferences`) e volta ao onboarding. Nada no
servidor é tocado. Sem isto o Cesar instalava o APK novo e continuava a ver as
mesmas máquinas que não são dele.

### O que **não** se tocou

`OperationsState.activeCollaboratorLimit` é `3` por omissão, e o painel mostra
"Colaboradores ativos / vagas: 0 / 3". Aquele 3 também não vem de nada que o
utilizador tenha escrito, mas **não é um bug de dados**: é o conceito de "vagas"
(limite de colaboradores activos), que o `saveCollaborator` faz cumprir e que
está coberto por testes. Trocá-lo pelo número declarado é uma decisão de
produto, não uma correcção — fica registada aqui como o próximo candidato se o
Cesar continuar a ver números que não reconhece.

## 5. Ajudantes de formato

`lib/core/format/campos.dart` — `textoOpcional`, `centsDeTexto`, `textoDeCents`,
`contagemDeTexto`. São gémeos públicos de quatro funções privadas do
`operational_pages.dart`. Duplicar quatro linhas cada é melhor, agora, do que
mexer num ficheiro que está a ser reescrito noutra frente; quando essa assentar,
aquele importa estes e os privados saem.

## 6. Por validar à mão

**Por fazer, para o Cesar**, depois de instalar o APK novo:

1. Painel de gestão → botão de lápis no canto ("Editar dados da empresa").
2. Os valores do onboarding aparecem preenchidos. Alterar um, **Guardar**, sair,
   voltar a entrar: o valor novo está lá.
3. Limpar o NIF, guardar, voltar: continua vazio (não ressuscita).
4. Pôr veículos a 0 e guardar: a área de Frota desaparece do menu. Pôr 1: volta.
5. Se o telemóvel ainda mostrar a "Mini escavadora 1.8T" ou o cliente
   "Construções Silva": **Repor dados desta app**. Depois disso o painel arranca
   a zeros e o onboarding começa de novo.
