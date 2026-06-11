# Copa Palpite

Projeto Flutter para palpites da Copa do Mundo com login Firebase/Google.

## Rodar no navegador

Para subir o backend local e o Flutter web juntos:

```powershell
.\scripts\run-local.ps1
```

Isso inicia:

```text
Backend: http://127.0.0.1:3000
Flutter: http://127.0.0.1:4200
```

Crie um `.env` na raiz do projeto com a URL da API hospedada:

```env
API_BASE_URL=https://sua-api-do-cloud-run.run.app
APP_CHECK_WEB_RECAPTCHA_SITE_KEY=sua-chave-recaptcha-v3-do-firebase-app-check
APP_CHECK_ANDROID_PROVIDER=play_integrity
```

No Windows, use:

```powershell
.\scripts\run-web.ps1
```

Depois abra no navegador:

```text
http://127.0.0.1:4200
```

Alternativa usando `localhost` como origem:

```powershell
.\scripts\run-web.ps1 -HostName localhost
```

Depois abra:

```text
http://localhost:4200
```

## Rodar no Android sem API local

Com `API_BASE_URL` apontando para a API hospedada no `.env`, rode:

```powershell
.\scripts\run-android.ps1
```

Se houver mais de um dispositivo/emulador conectado, liste os dispositivos:

```powershell
flutter devices
```

Depois informe o id desejado:

```powershell
.\scripts\run-android.ps1 -DeviceId "emulator-5554"
```

## Gerar APK Android

Para gerar um APK release apontando para a API hospedada:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-do-cloud-run.run.app"
```

O APK fica em:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Para gerar Android App Bundle em vez de APK:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-do-cloud-run.run.app" -Target appbundle
```

Em release, o App Check Android usa Play Integrity por padrao. Para testar APK instalado manualmente enquanto o Play Integrity/SHA-256 ainda nao estiver pronto no Firebase, gere um APK de diagnostico com o provider debug:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-do-cloud-run.run.app" -AndroidAppCheckProvider debug
```

Esse modo exige registrar o token debug no Firebase App Check e nao deve ser usado para publicacao.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
