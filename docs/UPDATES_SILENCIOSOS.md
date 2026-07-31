# Updates que não se dão por eles

Pedido do Cesar a 31/07/2026: *"quero ter updates silenciosos que não se dão por
eles. Aceita-se receber o update e depois continuamos a trabalhar. Nem que nos
peça autorização para reiniciar a app."*

Isto é desenho. Nada está implementado.

---

## O que acontece hoje

O banner mostra a versão nova e o botão abre o **browser** com o URL do APK
(`update_banner.dart:52`). A partir daí o Android trata disto como um download
qualquer: notificação, "ficheiro potencialmente perigoso", abrir a transferência,
ecrã de instalação, "Actualizar", esperar, "Abrir".

São seis ou sete toques e uma saída da app. É o oposto do pedido.

---

## Onde é que "silencioso" é possível, e onde não é

Convém separar as três fases, porque só uma é que é realmente difícil.

| Fase | Silenciosa? |
|---|---|
| **Descarregar** os 76 MB | **Sim, sempre.** É aqui que está quase toda a fricção percebida |
| **Instalar** | **Depende** — ver abaixo |
| **Reiniciar** | O instalador mata a app. Ou se reabre logo, ou fica para a próxima vez |

### A instalação, sem rodeios

Uma app fora da Play Store **não pode instalar-se a si própria sem
confirmação** — excepto num caso concreto:

- Precisa da permissão `REQUEST_INSTALL_PACKAGES` e do
  `PackageInstaller` nativo (Kotlin), em vez de abrir o browser.
- Em **Android 12+ (API 31)** existe
  `Session.setRequireUserAction(USER_ACTION_NOT_REQUIRED)`, que instala **sem
  perguntar nada** — mas só quando a app que instala é a **mesma que instalou a
  versão anterior** (é o "installer of record") e a assinatura bate certo.
- Consequência prática: **a primeira actualização por esta via ainda pede
  confirmação.** A partir daí, se foi o Punho a instalar, as seguintes passam a
  ser silenciosas de verdade.

Ou seja, o pedido é atingível — mas só a partir da segunda vez, e só em Android
12 ou superior. Em Android mais antigo há sempre um ecrã de confirmação do
sistema, e não há volta a dar.

---

## O caminho mais curto para o efeito que ele quer

Mesmo sem instalação silenciosa, **a maior parte da chatice desaparece com o
download em segundo plano**. Proposta por ordem:

1. **Descarregar assim que o banner aparece**, sem sair da app e sem interromper
   nada. O banner passa de *"Há versão nova"* para *"Versão nova pronta a
   instalar"*.
2. **Só em Wi-Fi por defeito.** São 76 MB. Descarregar isso nos dados móveis do
   gestor sem avisar é abusar da confiança dele — com opção para forçar.
3. **Instalar com `PackageInstaller`**, não com o browser. Passa dos seis toques
   para um.
4. **`USER_ACTION_NOT_REQUIRED` quando o Android deixar.** Da segunda
   actualização em diante deixa de haver toque nenhum.
5. **Reiniciar quando ele quiser.** O instalador mata a app; o que se pode
   escolher é o momento. Perguntar *"Instalar agora ou quando fechares?"* e, se
   for "quando fechares", instalar no `paused` seguinte.

Com 1+2+3 já se cumpre o essencial do pedido — recebe-se o update sem dar por
ele e só se decide o momento de reiniciar. O 4 é o que fecha o círculo.

---

## A alternativa que ninguém pensa e que resolve isto de graça

**Publicar na Play Store, mesmo que em canal fechado** (teste interno ou fechado,
que não é público e aceita a app tal como está).

A partir daí a Play Store trata das actualizações automáticas sozinha: sem
permissões perigosas, sem código nativo, sem `REQUEST_INSTALL_PACKAGES`, sem
"fonte desconhecida", e com actualizações verdadeiramente silenciosas em todos os
Android — não só no 12+.

Custos honestos: conta de programador (~25 € uma vez), revisão inicial de alguns
dias, e cada versão nova demora algumas horas a propagar em vez de ser imediata.
Os assets já existem — o `ic_launcher_512.png` foi gerado para isso na v0.0.15.

**Se o destino já é a Play Store**, construir um instalador próprio é trabalho
que se deita fora daqui a uns meses. Se o Punho vai continuar a ser distribuído
por APK a clientes que não passam pela loja, então o instalador próprio é o
caminho certo.

**É uma decisão de produto, não técnica.** Depende de para onde vai a
distribuição, e essa resposta é do Cesar.

---

## Riscos a não esquecer, seja qual for o caminho

- **Uma app que se instala a si própria tem de verificar o que instala.** O URL
  vem de `versoes_apps`, que é editável. Confirmar o SHA-256 do APK contra um
  valor guardado na mesma linha, antes de instalar, evita que uma linha errada
  (ou maliciosa) instale outra coisa qualquer.
- **`REQUEST_INSTALL_PACKAGES` é permissão sensível na Play Store** e exige
  justificação na ficha. Mais uma razão para decidir primeiro o destino.
- **Update obrigatório + instalação automática é uma combinação perigosa.** Se
  uma versão sair partida, tira-se toda a gente do ar sem forma de recuar. A
  regra que já ficou escrita na v0.0.17 — só uma resposta viva do servidor pode
  bloquear a app — passa a ser ainda mais importante.
