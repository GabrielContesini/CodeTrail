# CodeTrail Tablet

Aplicativo Flutter para tablet Android focado em organizacao de estudos para TI, com arquitetura em camadas, offline-first com Drift, sincronizacao com Supabase e estrutura SaaS pronta para cobranca recorrente com Stripe.

O app principal do produto fica na raiz deste repositorio. `CodeTrail-LandingPage/` e um projeto separado e nao faz parte do fluxo de billing implementado aqui.

## Visao Geral

- `lib/`: app Flutter principal.
- `supabase/schema.sql`: snapshot completo para instalacoes novas, incluindo billing.
- `supabase/migrations/20260316_add_billing_saas.sql`: migracao inicial do billing SaaS.
- `supabase/migrations/20260317_migrate_billing_to_stripe.sql`: migracao de troca de provider para Stripe.
- `supabase/functions/`: Edge Functions e camadas server-side do billing.
- `CodeTrail-LandingPage/`: landing page separada, mantida intacta.

## Arquitetura

- `core`: tema, constantes, servicos de bootstrap, sync, billing e utilitarios.
- `shared`: widgets reutilizaveis, extensoes e view models.
- `domain`: entidades e contratos de repositorio.
- `data`: Drift local, Supabase remoto e implementacoes de repositorio.
- `features`: modulos funcionais do produto, incluindo `billing`.

Estrategia offline-first preservada:

- gravacao local imediata no Drift;
- enfileiramento em `sync_queue`;
- flush da fila e pull remoto ao abrir o app;
- politica inicial de conflito: last-write-wins pelo cliente.

## Estrutura SaaS

### Banco

O banco inclui as tabelas de billing:

- `plans`
- `plan_features`
- `billing_config`
- `founder_eligibility`
- `customers`
- `subscriptions`
- `payments`
- `billing_events`

Regras principais no Postgres:

- todo novo usuario recebe `customer` e assinatura `free` automaticamente;
- trial simples pode ser habilitado globalmente em `billing_config`;
- Founding pode ser controlado por allowlist em `founder_eligibility`;
- helpers SQL centralizam estado de assinatura, trial, premium, grace period e feature access;
- RLS e triggers reforcam bloqueio server-side para recursos premium e limites quantitativos.

### Backend e billing

Camadas server-side:

- `supabase/functions/_shared/billing-provider.ts`: interface desacoplada do provider.
- `supabase/functions/_shared/stripe-provider.ts`: provider oficial Stripe.
- `supabase/functions/_shared/stripe-webhook.ts`: validacao da assinatura do webhook do Stripe.
- `supabase/functions/_shared/billing-data.ts`: persistencia e sincronizacao de billing.

Edge Functions:

- `billing-create-checkout`: cria checkout interno para `pro` ou `founding`.
- `billing-create-portal-session`: cria sessao do Stripe Customer Portal.
- `billing-cancel-subscription`: agenda cancelamento ao fim do ciclo.
- `billing-sync-subscription`: puxa status atual da assinatura e opcionalmente de uma invoice.
- `billing-webhook`: recebe notificacoes do Stripe, grava `billing_events` e processa de forma idempotente.

### App Flutter

Camadas de monetizacao dentro do app:

- `lib/domain/entities/billing_entities.dart`: entidades e status de billing.
- `lib/data/remote/billing_remote_data_source.dart`: RPCs e chamadas das Edge Functions.
- `lib/core/services/billing_entitlement_service.dart`: camada central de entitlement.
- `lib/features/billing/`: tela interna de assinatura e widgets de monetizacao.

Pontos de UX ja integrados no produto:

- tela interna `Configuracoes > Plano e cobranca`;
- badge do plano atual;
- banner de trial e CTA de upgrade;
- modal de upgrade;
- estados bloqueados para features premium;
- gates de acesso para analytics, flashcards, mind maps e fluxos de IA;
- checagem de limites para notas, projetos, flashcards e mind maps;
- botao para abrir o Stripe Customer Portal.

## Planos

### Free

- acesso basico ao produto;
- sem recursos premium;
- limites reduzidos;
- pode receber trial simples quando configurado globalmente.

### Pro

- acesso aos recursos premium;
- plano padrao para assinante pagante.

### Founding

- mesmo acesso do Pro;
- badge especial;
- preparado para preco promocional;
- exibido apenas para usuario elegivel.

## Setup

### Dependencias principais

- Flutter estavel com Material 3
- Riverpod
- go_router
- Supabase Auth/Postgres
- Drift + sqlite3_flutter_libs
- freezed + json_serializable
- fl_chart
- flutter_secure_storage

### Instalar dependencias Flutter

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

No Windows com o SDK local deste workspace:

```powershell
.\flutter\bin\flutter.bat pub get
.\flutter\bin\flutter.bat pub run build_runner build --delete-conflicting-outputs
```

## Banco de Dados

### Instalacao nova

Para um projeto novo do Supabase, execute:

1. `supabase/schema.sql`
2. `supabase/seed_tracks.sql`

### Base ja existente

Para atualizar um projeto que ja estava rodando antes do billing em Stripe:

1. aplique as migrations pendentes em `supabase/migrations/`;
2. aplique `supabase/migrations/20260316_add_billing_saas.sql` se ainda nao foi aplicada;
3. aplique `supabase/migrations/20260317_migrate_billing_to_stripe.sql`.

Com Supabase CLI:

```bash
supabase db push
```

## Variaveis de Ambiente

### App Flutter (`--dart-define`)

Obrigatorias:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Relacionadas ao billing:

- `BILLING_PROVIDER=stripe`
- `STRIPE_PUBLISHABLE_KEY`
- `TRIAL_DAYS_DEFAULT`
- `FOUNDING_PLAN_ENABLED=true|false`

Exemplo:

```powershell
.\flutter\bin\flutter.bat run `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON `
  --dart-define=BILLING_PROVIDER=stripe `
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx `
  --dart-define=TRIAL_DAYS_DEFAULT=7 `
  --dart-define=FOUNDING_PLAN_ENABLED=true
```

### Edge Functions / servidor

Configure estas variaveis como secrets do Supabase:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `BILLING_PROVIDER=stripe`
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `APP_BILLING_RETURN_URL`
- `STRIPE_PORTAL_RETURN_URL`

Exemplo:

```bash
supabase secrets set \
  SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  SUPABASE_ANON_KEY=SUA_CHAVE_ANON \
  SUPABASE_SERVICE_ROLE_KEY=SUA_CHAVE_SERVICE_ROLE \
  BILLING_PROVIDER=stripe \
  STRIPE_SECRET_KEY=sk_test_xxxxx \
  STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx \
  STRIPE_WEBHOOK_SECRET=whsec_xxxxx \
  APP_BILLING_RETURN_URL=https://seu-retorno-https \
  STRIPE_PORTAL_RETURN_URL=https://seu-retorno-https
```

Observacoes:

- `STRIPE_SECRET_KEY` e obrigatorio para checkout, customer portal, consulta de assinatura e sincronizacao.
- `STRIPE_WEBHOOK_SECRET` e obrigatorio em producao.
- em ambiente de teste, se `STRIPE_WEBHOOK_SECRET` nao estiver configurado, o webhook e aceito quando a chave do Stripe for `sk_test_...`.

## Deploy das Edge Functions

Funcoes incluidas:

- `billing-create-checkout`
- `billing-create-portal-session`
- `billing-cancel-subscription`
- `billing-sync-subscription`
- `billing-webhook`

Com CLI:

```bash
supabase functions deploy billing-create-checkout
supabase functions deploy billing-create-portal-session
supabase functions deploy billing-cancel-subscription
supabase functions deploy billing-sync-subscription
supabase functions deploy billing-webhook
```

O arquivo `supabase/config.toml` marca `billing-webhook` com `verify_jwt = false`, porque o Stripe chama o endpoint sem token do usuario.

## Fluxo de Billing

1. `handle_new_user()` cria o perfil e garante `customer` + assinatura `free`.
2. O app carrega `get_my_billing_snapshot()`.
3. O usuario logado acessa `Configuracoes > Plano e cobranca`.
4. O checkout chama `billing-create-checkout`.
5. O Stripe cria uma `Checkout Session` em modo `subscription`.
6. O retorno bruto do provider e persistido em `subscriptions`.
7. `billing-webhook` grava `billing_events` e sincroniza assinatura e invoices.
8. O app pode forcar refresh com `billing-sync-subscription`.
9. O botao `Gerenciar assinatura` chama `billing-create-portal-session` e abre o Stripe Customer Portal.

## Webhook do Stripe

Endpoint:

```text
https://<seu-projeto>.supabase.co/functions/v1/billing-webhook
```

Fluxo suportado:

- recebimento do payload bruto;
- validacao da assinatura quando `STRIPE_WEBHOOK_SECRET` estiver configurado;
- idempotencia por `event_id`;
- sincronizacao de assinatura;
- persistencia do historico de invoices/pagamentos;
- atualizacao de `status`, `status_detail`, `external_reference` e payload bruto.

Eventos principais tratados:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.paid`
- `invoice.payment_failed`
- `invoice.finalized`

## Como configurar o Stripe

1. Crie ou use uma conta Stripe.
2. Em `Developers > API keys`, copie:
   - `Publishable key`
   - `Secret key` de teste
3. Em `Billing > Customer portal`, ative o portal de clientes.
4. Em `Developers > Webhooks`, crie um endpoint apontando para:

```text
https://<seu-projeto>.supabase.co/functions/v1/billing-webhook
```

5. Selecione pelo menos estes eventos:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
   - `invoice.finalized`
6. Copie o `Signing secret` do endpoint e configure em `STRIPE_WEBHOOK_SECRET`.
7. Para testes, use o modo de teste do Stripe e um cartao de teste oficial.

## Teste local do webhook

1. sirva as functions localmente:

```bash
supabase functions serve --env-file supabase/.env.local
```

2. exponha a URL local com um tunel, por exemplo `ngrok` ou `cloudflared`.
3. aponte o webhook do Stripe para:

```text
http://127.0.0.1:54321/functions/v1/billing-webhook
```

4. conclua um checkout de teste.
5. confirme que houve registro em `billing_events`, `subscriptions` e `payments`.

## Testes de Fluxo

### Novo usuario, Free e trial

1. crie uma conta nova;
2. confirme que existe um `customer` e uma `subscription` no plano `free`;
3. se `billing_config.trial_enabled = true`, verifique `trial_ends_at`.

### Upgrade para Pro

1. entre em `Configuracoes > Plano e cobranca`;
2. clique em `Assinar Pro`;
3. conclua o checkout de teste no Stripe;
4. aguarde o webhook ou clique em `Sincronizar status`;
5. valide que o snapshot mudou para `pro` e que features premium foram liberadas.

### Upgrade para Founding

1. marque o usuario como elegivel em `founder_eligibility`;
2. abra a tela de billing;
3. clique em `Migrar para Founding`;
4. conclua o checkout no Stripe;
5. valide badge e permissao premium.

### Cancelamento

1. com uma assinatura paga ativa, abra a tela de billing;
2. clique em `Cancelar renovacao`;
3. sincronize o status;
4. confirme `cancel_at_period_end = true` ou status equivalente do Stripe;
5. o acesso premium deve permanecer ate `current_period_end`, conforme a regra atual.

### Customer Portal

1. com uma assinatura paga, clique em `Gerenciar assinatura`;
2. confirme abertura do Stripe Customer Portal;
3. teste alteracoes de pagamento ou cancelamento no portal;
4. volte ao app e use `Sincronizar status` se necessario.

### Mudanca de status

1. use o dashboard do Stripe ou reenfileire eventos de teste;
2. confirme atualizacao de `billing_events`;
3. valide transicao em `subscriptions.status` e `payments.status`.

## Configuracao Interna e Admin

Nao existe painel publico nem landing de planos. A configuracao operacional fica no banco.

### Ativar ou desativar trial global

```sql
update public.billing_config
set trial_enabled = true,
    trial_days_default = 7
where id = 'default';
```

### Habilitar ou ocultar Founding

```sql
update public.billing_config
set founding_plan_enabled = true,
    founding_requires_allowlist = true
where id = 'default';
```

### Marcar usuario como elegivel ao Founding

Por usuario:

```sql
insert into public.founder_eligibility (user_id, email, is_eligible, notes)
values ('SEU-USER-ID', 'usuario@exemplo.com', true, 'allowlist manual');
```

Por email:

```sql
insert into public.founder_eligibility (email, is_eligible, notes)
values ('usuario@exemplo.com', true, 'allowlist manual');
```

### Alterar limites por plano

Exemplo para mudar o limite de projetos do Free:

```sql
update public.plan_features pf
set limit_value = 5
from public.plans p
where pf.plan_id = p.id
  and p.code = 'free'
  and pf.feature_key = 'projects_limit';
```

## Onde Fica Cada Parte

- provider Stripe: `supabase/functions/_shared/stripe-provider.ts`
- webhook: `supabase/functions/billing-webhook/index.ts`
- funcoes internas de cobranca: `supabase/functions/billing-create-checkout/index.ts`, `supabase/functions/billing-create-portal-session/index.ts`, `supabase/functions/billing-cancel-subscription/index.ts`, `supabase/functions/billing-sync-subscription/index.ts`
- entidades e snapshot: `lib/domain/entities/billing_entities.dart`
- guards e entitlements: `lib/core/services/billing_entitlement_service.dart`
- tela interna de assinatura: `lib/features/billing/presentation/billing_screen.dart`
- modal, badge, banner e estados bloqueados: `lib/features/billing/presentation/widgets/`

## Pontos Que Dependem de Credenciais Reais

Dependem de credenciais ou configuracao externa valida:

- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `APP_BILLING_RETURN_URL`
- `STRIPE_PORTAL_RETURN_URL`
- webhook cadastrado corretamente no Stripe
- portal do Stripe habilitado no dashboard

Sem isso, o app continua funcional no plano Free, mas checkout, customer portal, sincronizacao com provider e webhooks nao fecham o ciclo end-to-end.

## Gerar APK

APK local instalavel:

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

Saida esperada:

```text
artifacts/debug/CodeTrail-<versao+build>-debug.apk
artifacts/release/CodeTrail-<versao+build>-release.apk
```

Observacoes:

- o projeto esta configurado para compilar `release` com a chave de debug para instalacao local;
- para distribuicao real, substitua a configuracao de assinatura no `android/app/build.gradle.kts`;
- se voce gerar mais de uma APK com a mesma versao, o script cria sufixos `-r2`, `-r3` e assim por diante para nao sobrescrever o artefato anterior.

## Verificacao Local

Comandos validados neste workspace:

```powershell
.\flutter\bin\flutter.bat analyze lib
.\flutter\bin\flutter.bat test test\features\billing\billing_entitlement_service_test.dart
```
