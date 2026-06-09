# Copa Palpite API

Backend Nest para centralizar integracoes externas, incluindo a API WC2026.

## Rodar localmente

```powershell
cd api
npm install
npm run start:dev
```

Endpoint inicial:

```text
GET http://127.0.0.1:3000/matches/world-cup-2026
```

## WC2026 API

Tambem e possivel usar a API dedicada ao World Cup 2026 em https://api.wc2026api.com/. Para ativar use as variaveis de ambiente:

- `NODE_ENV` - use `production` no deploy para impedir fallback mockado sem chave
- `CORS_ORIGINS` - origens permitidas separadas por virgula, exemplo `https://copa-palpite.web.app,https://copa-palpite.firebaseapp.com`
- `FIREBASE_PROJECT_ID` - projeto Firebase
- `FIREBASE_DATABASE_URL` - URL do Realtime Database
- `FIREBASE_SERVICE_ACCOUNT_BASE64` ou `FIREBASE_SERVICE_ACCOUNT` - credencial Admin para validar tokens e escrever no banco pelo servidor
- `WC2026_BASE_URL` (opcional) - padrao `https://api.wc2026api.com`
- `WC2026_API_KEY` - chave Bearer fornecida pelo servico

Quando `WC2026_API_KEY` estiver presente o backend usara esse servico. Sem a chave, ele retorna dados mockados apenas em desenvolvimento local. Em producao, a API falha explicitamente para evitar deploy com dados falsos.

## Deploy

Configure as mesmas variaveis do `.env.example` no provedor onde a API sera publicada. O app Flutter precisa ser compilado apontando para essa API:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://sua-api-em-producao
```

Para Firebase Hosting, depois do build:

```powershell
firebase deploy --only hosting
```

Publique tambem as regras do Realtime Database:

```powershell
firebase deploy --only database
```
