# Copa Palpite API

Backend Nest para centralizar integracoes externas, incluindo API-Football.

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

Também é possível usar a API dedicada ao World Cup 2026 em https://api.wc2026api.com/. Para ativar use as variáveis de ambiente:

- `WC2026_BASE_URL` (opcional) — padrão `https://api.wc2026api.com`
- `WC2026_API_KEY` — chave Bearer fornecida pelo serviço

Quando `WC2026_API_KEY` estiver presente o backend usará esse serviço (com fallback para `API_FOOTBALL_KEY`).
