# Checklist De Build Final

## Variaveis

### `.env` na raiz

- [ ] Definir `API_BASE_URL=https://sua-api-cloud-run`.
- [ ] Definir `APP_CHECK_WEB_RECAPTCHA_SITE_KEY=sua-chave-recaptcha-v3-do-firebase-app-check`.
- [ ] Definir `APP_CHECK_ANDROID_PROVIDER=play_integrity`.
- [ ] Nao colocar `WC2026_API_KEY`, service account, senha, token privado ou chave Admin no `.env` usado pelo Flutter.

### Cloud Run

- [ ] Definir `NODE_ENV=production`.
- [ ] Definir `FIREBASE_PROJECT_ID=copa-palpite`.
- [ ] Definir `FIREBASE_DATABASE_URL=https://copa-palpite-default-rtdb.firebaseio.com`.
- [ ] Definir `FIREBASE_APP_CHECK_REQUIRED=true`.
- [ ] Definir `FIREBASE_APP_CHECK_CONSUME_TOKENS=false`.
- [ ] Definir `WC2026_BASE_URL=https://api.wc2026api.com`.
- [ ] Definir `WC2026_API_KEY=...`.
- [ ] Definir `CORS_ORIGINS=https://copa-palpite.web.app,https://copa-palpite.firebaseapp.com`.
- [ ] Guardar `FIREBASE_SERVICE_ACCOUNT_BASE64`/`FIREBASE_SERVICE_ACCOUNT` somente no ambiente do backend.

## Firebase

- [ ] Publicar regras do Realtime Database:

```powershell
firebase deploy --only database --project copa-palpite
```

- [ ] Publicar regras do Storage:

```powershell
firebase deploy --only storage --project copa-palpite
```

- [ ] Confirmar App Check para Android `com.copapalpite.app`.
- [ ] Confirmar Play Integrity registrado.
- [ ] Confirmar SHA-256 do keystore release cadastrado no Firebase.
- [ ] Confirmar Storage ativo e regras publicadas.
- [ ] Confirmar App Check para Web com reCAPTCHA v3.
- [ ] Ativar enforcement do App Check para Realtime Database, Storage e APIs Firebase usadas pelo app.
- [ ] Cadastrar os dominios do Hosting em Firebase Auth > Authorized domains.

## API

- [ ] Validar API:

```powershell
cd api
npm run lint
```

- [ ] Fazer redeploy no Cloud Run:

```powershell
cd /d C:\Users\JONATAS\Documents\projetos\flutter_copadomundo
gcloud run deploy copa-palpite-api --source api --region southamerica-east1 --allow-unauthenticated
```

- [ ] Testar endpoint:

```powershell
Invoke-WebRequest "https://sua-api/matches/world-cup-2026"
```

## Flutter

- [ ] Rodar analise estatica:

```powershell
flutter analyze
```

- [ ] Rodar testes:

```powershell
flutter test
```

- [ ] Testar em device/emulador:

```powershell
.\scripts\run-android.ps1 -DeviceId emulator-5554
```

## Build Web

- [ ] Gerar build web release:

```powershell
.\scripts\build-web-release.ps1
```

- [ ] Conferir que o build gerado fica em:

```text
build\web
```

- [ ] Publicar Firebase Hosting:

```powershell
firebase deploy --only hosting --project copa-palpite
```

- [ ] Testar no dominio final:

```text
https://copa-palpite.web.app
```

## Assinatura Android

- [ ] Confirmar existencia de `release-keystore.jks`.
- [ ] Confirmar existencia de `android/key.properties`.
- [ ] Guardar backup seguro dos dois arquivos.
- [ ] Usar sempre o mesmo keystore para atualizacoes fora da Play Store.

## Build APK

Para distribuicao manual:

- [ ] Gerar APK release:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-cloud-run"
```

- [ ] Confirmar APK gerado em:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## Build AAB

Para Play Store:

- [ ] Gerar AAB release:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-cloud-run" -Target appbundle
```

- [ ] Confirmar AAB gerado em:

```text
build\app\outputs\bundle\release\app-release.aab
```

## Teste Final No App

- [ ] Login Google.
- [ ] Login email/senha.
- [ ] Carregar matches reais.
- [ ] Salvar palpite.
- [ ] Atualizar palpite antes do inicio.
- [ ] Confirmar bloqueio apos inicio.
- [ ] Leaderboard com paginacao.
- [ ] Foto de perfil via Storage.
- [ ] Logout/login e verificar persistencia.

## Play Store

- [ ] Criar app no Play Console.
- [ ] Preencher descricao.
- [ ] Preencher screenshots.
- [ ] Preencher icone.
- [ ] Preencher politica de privacidade.
- [ ] Preencher Data Safety.
- [ ] Preencher publico-alvo.
- [ ] Subir `.aab`.
- [ ] Comecar internal/closed testing.
- [ ] Depois solicitar producao.
