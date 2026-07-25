# Prompt Code Punho — sprint: cliente de licenciamento (registar-terminal + validar-licenca)

> Cola numa sessão nova do Claude Code em `D:\Punho\`.
> Branch: **`feature/licenciamento`** a partir de `main`.
> Alvo: adicionar cliente de licenciamento ao Punho. Chama Edge Functions no Supabase (mesmo do Control) para auto-onboarding e validação periódica. Trial 40 dias. Cross-platform (Android + Windows). **NÃO** bumpar `pubspec.yaml` para além do necessário para deps novas. **NÃO** fazer release.

---

## Contexto

- **Punho** é Flutter cross-platform (Android + Windows). Auto-update já feito (`lib/core/updates/`, `lib/features/updates/`).
- **Supabase:** projecto `oefqbkhioncakojipqyx` (mesmo do WashInvoice Control). `SUPABASE_URL` e `SUPABASE_ANON_KEY` já vêm via `--dart-define` (workflow) ou `.env` local (dev). `SupabaseConfig.enabled` já lá está.
- **Edge Functions já deployed** (versão 6, multi-app):
  - `registar-terminal` — recebe `{machine_id, app, info_host?}`. Retorna trial 40 dias para `app='punho'`. Idempotente por `(machine_id, app)`.
  - `validar-licenca` — recebe `{machine_id, app}`. Retorna `{estado, plano, validade, nome, nif, dias_restantes, oferta, tier, preferencias_features}`. Estados: `activa | expirada | inactiva | inexistente`.
- **Padrão de referência:** o WashInvoice POS já tem este cliente feito em `D:\WashFactura\lib\services\licenca\`. **Não copies literalmente** — adapta ao contexto Punho (cross-platform, arquitectura Riverpod já existente).
- **`machine_id`** — no POS é hash SHA256 do hostname Windows. No Punho tem de ser cross-platform:
  - Windows: mesmo padrão (hostname via `Platform.localHostname` + SHA256)
  - Android: `device_info_plus.androidId` (o `ANDROID_ID` do sistema)
  - Persistente entre arranques, único por dispositivo.

---

## Autorizações

- Adicionar deps: `device_info_plus`, `crypto` (para SHA256). Ambas do pub oficial.
- Criar pastas novas: `lib/core/licenca/`, `lib/features/licenca/`.
- Editar `main.dart` (arranque + provider override), `lib/features/shell/presentation/app_shell.dart` (para injectar banner de licença).
- **Não** alterar `update_service.dart`, `update_banner.dart`, `supabase_operational_sync.dart`, `guidance_engine.dart` ou outros core existentes.
- **Não** bumpar `pubspec.yaml version` (fica em `1.0.0+1` até Cesar decidir tag nova).

---

## Fase 1 — Modelo + serviços

### 1a. `lib/core/licenca/licenca_info.dart`

```dart
enum EstadoLicenca { activa, expirada, inactiva, inexistente }

class LicencaInfo {
  final EstadoLicenca estado;
  final String app;         // sempre 'punho'
  final String? plano;      // 'trial' | 'mensal' | ... (mesmo enum do POS)
  final String? nif;
  final String? nome;
  final DateTime? validade;
  final int diasRestantes;
  final bool oferta;
  final String machineId;
  final String tier;        // 'base' | 'pro'
  final Map<String, dynamic> preferenciasFeatures;

  const LicencaInfo({...});

  bool get funcional => estado == EstadoLicenca.activa;
  bool get emTrial => plano == 'trial' && funcional;

  factory LicencaInfo.fromJson(Map<String, dynamic> json) => ...;
}
```

### 1b. `lib/core/licenca/machine_id.dart`

Cross-platform. Cachear em `SharedPreferences` para não recalcular sempre.

```dart
Future<String> resolverMachineId() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('punho_machine_id');
  if (cached != null && cached.length >= 8) return cached;

  String seed;
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    seed = 'android:${info.id}';           // ANDROID_ID
  } else if (Platform.isWindows) {
    final info = await DeviceInfoPlugin().windowsInfo;
    seed = 'windows:${info.computerName}:${info.deviceId}';
  } else {
    seed = 'unknown:${DateTime.now().microsecondsSinceEpoch}';
  }

  final hash = sha256.convert(utf8.encode(seed)).toString();
  await prefs.setString('punho_machine_id', hash);
  return hash;
}
```

### 1c. `lib/core/licenca/licenca_service.dart`

```dart
class PunhoLicencaService {
  PunhoLicencaService(this._client);
  final SupabaseClient _client;

  /// Regista o terminal no arranque. Idempotente do lado do servidor.
  Future<void> registarTerminal(String machineId) async {
    if (!SupabaseConfig.enabled) return;
    try {
      await _client.functions
          .invoke('registar-terminal', body: {
            'machine_id': machineId,
            'app': 'punho',
            'info_host': await _colherInfoHost(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // fail-silent — utilizador não deve ver stack traces de rede
      debugPrint('registar-terminal falhou: $e');
    }
  }

  /// Valida a licença. Retorna null se falhar (offline, timeout).
  Future<LicencaInfo?> validar(String machineId) async {
    if (!SupabaseConfig.enabled) return null;
    try {
      final resp = await _client.functions
          .invoke('validar-licenca', body: {
            'machine_id': machineId,
            'app': 'punho',
          })
          .timeout(const Duration(seconds: 10));
      final data = resp.data;
      if (data is! Map) return null;
      return LicencaInfo.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('validar-licenca falhou: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _colherInfoHost() async {
    // Nome do host + plataforma + versão da app. Sem dados sensíveis.
    // ...
  }
}
```

### 1d. Testes

- `test/core/licenca/licenca_service_test.dart` — mock de `SupabaseClient.functions.invoke`, verifica que:
  - Body enviado inclui `app: 'punho'` e `machine_id`
  - Sucesso → retorna `LicencaInfo`
  - Falha (network) → retorna null (sem excepção)
- `test/core/licenca/machine_id_test.dart` — verifica caching em SharedPreferences (usa `SharedPreferences.setMockInitialValues`).

---

## Fase 2 — Provider + estado

### 2a. `lib/core/licenca/licenca_provider.dart`

```dart
final licencaServiceProvider = Provider<PunhoLicencaService>((ref) {
  return PunhoLicencaService(Supabase.instance.client);
});

final machineIdProvider = FutureProvider<String>((ref) => resolverMachineId());

final licencaProvider = FutureProvider<LicencaInfo?>((ref) async {
  final machineId = await ref.watch(machineIdProvider.future);
  final service = ref.watch(licencaServiceProvider);
  return service.validar(machineId);
});

/// Re-valida a licença de X em X horas. Timer arranca no `main`.
final licencaRefreshProvider = Provider<void>((ref) {
  Timer.periodic(const Duration(hours: 6), (_) {
    ref.invalidate(licencaProvider);
  });
  return;
});
```

### 2b. Arranque em `main.dart`

Após `Supabase.initialize`:

```dart
// Auto-onboarding no primeiro arranque
final machineId = await resolverMachineId();
await container.read(licencaServiceProvider).registarTerminal(machineId);
```

Não bloquear boot se falhar. É fail-silent.

---

## Fase 3 — Banner de licença

### 3a. `lib/features/licenca/presentation/licenca_banner.dart`

Padrão análogo ao `PunhoUpdateBanner` já existente. Cores:

| Estado | Cor | Mensagem |
|---|---|---|
| `activa` + trial + dias > 10 | (não mostrar) | — |
| `activa` + trial + dias <= 10 | amarelo (warningContainer) | "Trial termina em N dias. Contactar suporte." |
| `activa` + trial + dias <= 3 | laranja | "Trial termina em N dias — contactar já." |
| `expirada` | vermelho | "Licença expirada. A app está em modo limitado." |
| `inactiva` | vermelho | "Licença suspensa. Contactar suporte." |
| `inexistente` | cinza | "Terminal por registar. A tentar registo…" (tenta `registarTerminal` de novo) |

Botão "Contactar" em todos → `mailto:cesarmendes78@gmail.com?subject=Licença Punho`.

### 3b. Integrar em `lib/features/shell/presentation/app_shell.dart`

Colocar `LicencaBanner` **por cima** do `PunhoUpdateBanner` (licença é mais prioritária que update). Ambos usam `ConsumerWidget` já.

### 3c. Testes

- `test/features/licenca/licenca_banner_test.dart`:
  - Estado `activa + dias > 10` → banner não aparece
  - Estado `activa + dias <= 3` → banner laranja com "3 dias"
  - Estado `expirada` → banner vermelho + botão contactar
  - Estado `inexistente` → banner cinza a tentar registo

---

## Fase 4 — Comportamento "modo limitado" (licença expirada)

**Decisão pendente para Cesar** — na 1ª iteração, `expirada` **não bloqueia** funcionalidade, só mostra banner vermelho persistente. Só bloquear em iteração futura quando houver primeiro cliente pagante que não renove.

Implementação nesta fase: **nenhum bloqueio efectivo**. Apenas o banner. Documentar no `docs/LICENCIAMENTO.md` (novo ficheiro) que o modo limitado ainda não está implementado (fica para sprint futuro após primeiro cliente pagante).

---

## Fase 5 — Documentação

### 5a. `docs/LICENCIAMENTO.md` (novo)

```markdown
# Punho — Licenciamento

Punho reutiliza a infra do WashInvoice Control (mesmo Supabase, mesmas EFs
`registar-terminal` e `validar-licenca` v6+, com `app='punho'`).

## Auto-onboarding

Primeiro arranque:
1. Punho resolve `machine_id` (hash SHA256 do hostname/androidId).
2. Chama `registar-terminal` com `{machine_id, app: 'punho', info_host}`.
3. Control cria linha em `licencas` com `app='punho'`, `plano='trial'`,
   validade = hoje + 40 dias, `pendente_revisao=true`.
4. Cesar vê a instalação no Control (sprint UI multi-app #186).

## Validação

Cada arranque + cada 6h:
1. `validar-licenca` com `{machine_id, app: 'punho'}`.
2. Se estado != `activa` → banner apropriado.

## Modo limitado (futuro)

Ainda não implementado. Iteração futura vai desactivar features quando
`estado == expirada`, mas manter leitura de dados históricos.

## Renovação

Utilizador clica "Contactar" no banner → email para Cesar. Cesar prolonga
manualmente no Control (mesmo ecrã já usado para POS).
```

### 5b. Actualizar `docs/AUDITORIA_E_PLANO_DO_PRODUTO.md`

Se este ficheiro tem secção de "licenciamento" ou "produto", actualizar com:
- Trial 40 dias (não free)
- Auto-onboarding automático no arranque
- Reutiliza infra Control

---

## Fase 6 — Verificação (obrigatória antes de PR)

1. `flutter pub get`
2. `flutter test` — todos verdes, sem regressões nos updates existentes
3. `flutter analyze` — limpo
4. Executar app localmente (`flutter run -d windows`) com `.env` configurado:
   - Confirmar que `registar-terminal` foi chamado ao arranque (log console)
   - Confirmar que `validar-licenca` foi chamado
   - Confirmar que banner licença aparece se estado != activa
5. Executar em Android (emulador ou dispositivo):
   - Mesma verificação
   - Confirmar que `machine_id` é diferente do Windows (é o ANDROID_ID)
6. `git status` — só ficheiros novos + edições em `main.dart` e `app_shell.dart`
7. Push para `origin/feature/licenciamento`. **Não fazer merge para `main` nem tag** — Cesar decide.

---

## Fora de âmbito (NÃO fazer neste sprint)

- Bloquear features quando licença expirada. Não. Só banner.
- Integração com sistema de pagamento (Stripe, MB Way, etc.). Não.
- Ecrã de "gerir a minha licença" dentro da app. Não. Iteração futura.
- Tabela de renovações. Não. Só quando primeiro cliente pagante existir.
- Push notifications da licença. Não. Fica com o Control ao Cesar.
- Alterações ao Control. Não. Este sprint é só Punho.
- Bump `pubspec.yaml` version. Não. Fica em 1.0.0+1.

---

## Checklist Cesar (para depois deste sprint fechar)

- [ ] Merge feature/licenciamento → main
- [ ] Tag v0.0.2 → workflow release automático (Inno + APK)
- [ ] Inserir linhas na `versoes_apps` para punho 0.0.2 (windows + android) — Cesar avisa Cowork
- [ ] Testar auto-update de 0.0.1 → 0.0.2 num terminal existente
- [ ] Testar auto-onboarding no primeiro arranque de um terminal novo
- [ ] Ver a linha criada em `licencas` no Supabase (`app='punho'`, `validade=hoje+40d`)

---

**Fim do prompt.** Se algo aqui contradizer o código real que encontrares, **para e reporta ao Cesar antes de decidir sozinho**.
