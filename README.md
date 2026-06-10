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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
