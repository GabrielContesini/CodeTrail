# CodeTrail Tablet

Aplicativo Flutter para tablet Android focado em organização de estudos para TI, com arquitetura em camadas, offline-first com Drift e sincronização com Supabase.

## Arquitetura

- `core`: tema, constantes, serviços de bootstrap, sync e utilitários.
- `shared`: widgets reutilizáveis, extensões e view models.
- `domain`: entidades e contratos de repositório.
- `data`: Drift local, Supabase remoto e implementações de repositório.
- `features`: autenticação, onboarding, dashboard, sessões, trilhas, tarefas, revisões, projetos, analytics e settings.

Estratégia offline-first:

- gravação local imediata no Drift;
- enfileiramento em `sync_queue`;
- flush da fila e pull remoto ao abrir o app;
- política inicial de conflito: last-write-wins pelo cliente.

## Árvore principal

```text
lib/
  core/
    constants/
    errors/
    router/
    services/
    theme/
    utils/
  shared/
    extensions/
    models/
    widgets/
  features/
    analytics/
    auth/
    dashboard/
    onboarding/
    projects/
    reviews/
    settings/
    splash/
    study_plans/
    study_sessions/
    tasks/
    tracks/
  data/
    local/
    remote/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
supabase/
  schema.sql
  seed_tracks.sql
```

## Dependências principais

- Flutter estável com Material 3
- Riverpod
- go_router
- Supabase Auth/Postgres
- Drift + sqlite3_flutter_libs
- freezed + json_serializable
- fl_chart
- flutter_secure_storage

## Configuração do ambiente

1. Instale Flutter estável e Android SDK.
2. Crie um projeto no Supabase.
3. Execute o SQL de [schema.sql](supabase/schema.sql).
4. Execute o seed de [seed_tracks.sql](supabase/seed_tracks.sql).
5. Rode os comandos:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

6. Inicie o app com `dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

No Windows com o SDK local deste workspace:

```powershell
.\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

Alternativa local mais prática:

1. copie [supabase.example.json](C:\Users\gabri\Documents\projetos\CodeTrail\env\supabase.example.json) para `env/supabase.local.json`;
2. preencha URL e chave;
3. rode:

```powershell
.\scripts\run_app.ps1
```

## Gerar APK

APK local instalável:

```powershell
.\flutter\bin\flutter.bat build apk --release `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

Ou usando o arquivo local:

```powershell
.\scripts\build_debug_apk.ps1
.\scripts\build_release_apk.ps1
```

Saída esperada:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Observações:

- o projeto está configurado para compilar `release` com a chave de debug para instalação local;
- para distribuição real, substitua a configuração de assinatura no `android/app/build.gradle.kts`.

## CI/CD

Workflows GitHub Actions incluídos:

- `CI`: valida push/PR com `pub get`, `build_runner`, `analyze`, `test` e build `debug`
- `CD Release`: gera APK `release` em `tag` ou `workflow_dispatch` e publica artefato

Arquivos:

- `.github/workflows/ci.yml`
- `.github/workflows/cd-release.yml`

Configuração recomendada no GitHub:

1. crie um repositório Git e suba este projeto
2. em `Settings > Secrets and variables > Actions > Variables`, adicione:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. para publicar release automática, crie uma tag como `v1.0.0`

Comportamento dos pipelines:

- `CI` sobe um artefato `CodeTrail-debug-apk`
- `CD Release` sobe um artefato `CodeTrail-release-<versao>`
- em `tag`, o workflow também cria uma GitHub Release com o APK anexado

Observação:

- o APK `release` gerado no GitHub Actions usa a configuração atual do projeto; para distribuição pública real, configure assinatura própria no Android

## Banco e sync

- Catálogo de trilhas, skills e módulos é semeado localmente e pode ser replicado no Supabase.
- Dados do usuário são persistidos localmente mesmo offline.
- A sincronização é disparada no bootstrap, após CRUD e ao recuperar conexão.
- Para notas sincronizarem com o Supabase, aplique também `supabase/migrations/20260307_add_study_notes.sql`.

## Verificação local

Comandos já executados neste workspace:

```powershell
.\flutter\bin\flutter.bat pub run build_runner build --delete-conflicting-outputs
.\flutter\bin\flutter.bat analyze lib test
```
