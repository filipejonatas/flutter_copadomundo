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

## API-Football

Para Copa do Mundo 2026, a API-Football usa:

```text
league=1
season=2026
```

Endpoint que sera usado depois:

```text
GET https://v3.football.api-sports.io/fixtures?league=1&season=2026
```

A chave da API deve ficar somente neste backend, em `API_FOOTBALL_KEY`.
