# Smoke antes de anunciar

Isto corre-se **depois** de `scripts/release.sh` e **antes** de
`scripts/update-release-catalog.sh`. É o único momento em que um APK partido
ainda não chegou a ninguém: até o catálogo correr, a versão existe no GitHub e
mais nada. Depois de correr, entra sozinha em todos os telemóveis.

Não é uma campanha de testes — para isso está o
[PLANO_DE_TESTES_2026-08-02.md](PLANO_DE_TESTES_2026-08-02.md). São os quinze
minutos que separam "compilou" de "funciona".

## Antes de começar

```bash
adb install -r dist/punho-android-vX.Y.Z.apk
```

Instalar **por cima** da versão anterior, não numa app limpa: é assim que o
utilizador a vai receber, e é aí que aparecem os defeitos de migração de dados
que uma instalação de raiz nunca mostra.

Se o `adb install` falhar com `INSTALL_FAILED_USER_RESTRICTED`, ver
`feedback_miui-instalacao-usb-expira` — no MIUI é o interruptor "Instalar via
USB", não o APK.

## Os fluxos

Marcar cada um. Um só que falhe e o catálogo **não** corre.

- [ ] **1. Arranca.** Abrir a app a frio. Chega ao ecrã inicial sem ecrã branco,
      sem erro vermelho, sem ficar no logo. *(É este que apanha um release sem
      `--dart-define`: sem Supabase a app arranca e não se queixa — só nunca
      sincroniza.)*
- [ ] **2. Versão certa.** Perfil → a versão apresentada é a que se acabou de
      publicar. Se disser a anterior, instalou-se o APK errado e todo o resto
      deste smoke não vale nada.
- [ ] **3. Sessão preservada.** Quem já tinha sessão iniciada continua com ela
      depois da actualização. Não deve pedir login outra vez.
- [ ] **4. Cadeado.** Fechar e reabrir a app: pede PIN ou biometria e aceita-os.
      *(O PIN vive no Keystore; uma mudança de assinatura ou de armazenamento
      parte isto em silêncio.)*
- [ ] **5. Os dados continuam lá.** Clientes, máquinas e reservas de antes da
      actualização aparecem todos. Contar um deles e confirmar o número.
- [ ] **6. Criar.** Criar um cliente novo e uma reserva nova. Aparecem na lista
      imediatamente.
- [ ] **7. Anexar ficheiro.** Registar uma despesa com comprovativo, ou uma foto
      numa máquina. O ficheiro sobe e volta a abrir. *(Depende do bucket
      `punho-documentos` existir — já falhou em produção por não existir.)*
- [ ] **8. Sincroniza mesmo.** Com o segundo aparelho ou o Control: o que se
      criou no passo 6 aparece do outro lado. Não basta a app não dar erro —
      é preciso ver o registo chegar.
- [ ] **9. Aguenta ficar sem rede.** Modo de avião ligado, criar um registo,
      desligar o modo de avião. O registo sobe sozinho e não duplica.
- [ ] **10. Números certos.** Abrir o painel de KPIs e confirmar que os valores
      batem com o que se acabou de criar — e que nenhum campo de dinheiro
      mostra `0,00 €` onde devia dizer "por apurar".

## Depois

Só com os dez marcados:

```bash
./scripts/update-release-catalog.sh X.Y.Z <build>
```

E o passo que fecha o círculo, que não está na lista acima porque só é possível
depois do catálogo:

- [ ] **11. O update chega.** Num aparelho com a versão **anterior** instalada,
      abrir a app: tem de anunciar a nova versão e instalá-la até ao fim pelo
      botão, sem cair para o browser. *(Se cair para o browser, falta o `sha256`
      no catálogo.)*

## Se algo falhar

Não há nada para desfazer enquanto o catálogo não correr — é esse o ponto de
todo este arranjo. Deixa-se a release no GitHub, corrige-se, e publica-se
`X.Y.(Z+1)`. Nunca mover a tag: o gatilho
`trg_versoes_apps_release_integrity` recusa-o do lado da base de dados, e uma
tag publicada é imutável por decisão, não por acidente.
