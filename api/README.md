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

- `WC2026_BASE_URL` (opcional) - padrao `https://api.wc2026api.com`
- `WC2026_API_KEY` - chave Bearer fornecida pelo servico

Quando `WC2026_API_KEY` estiver presente o backend usara esse servico. Sem a chave, ele retorna dados mockados para desenvolvimento local.
