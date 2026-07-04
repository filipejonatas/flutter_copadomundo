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
- `PLAYOFF_ADMIN_SECRET` - segredo forte usado por scripts/rotinas para avancar o mata-mata sem login do app
- `AUTOMATION_MIN_REFRESH_MINUTES` (opcional) - intervalo minimo entre consultas reais a API externa no endpoint de automacao; padrao `25`

Quando `WC2026_API_KEY` estiver presente o backend usara esse servico. Sem a chave, ele retorna dados mockados apenas em desenvolvimento local. Em producao, a API falha explicitamente para evitar deploy com dados falsos.

## Avancar o mata-mata

Depois que todos os jogos de uma fase terminarem, avance a chave oficial:

```powershell
cd api
npm run advance:playoff -- --round round_of_32
```

Use `--force` apenas para correcao manual antes da API marcar todos os jogos como finalizados. Para agendar, configure `API_BASE_URL` ou `PLAYOFF_API_BASE_URL` e `PLAYOFF_ADMIN_SECRET` no ambiente do job e execute o mesmo comando com a rodada desejada.

## Recalcular o leaderboard

A tela de leaderboard apenas le os dados persistidos em `/scores`; ela nao recalcula nem sobrescreve pontuacao. Para atualizar a pontuacao geral, rode a rotina administrativa:

```powershell
cd api
npm run recalculate:leaderboard
```

Essa rotina busca jogos frescos da API externa, calcula a pontuacao em memoria, salva um snapshot anterior em `/scoreSnapshots/{timestamp}` e so entao sobrescreve `/scores`. O retorno mostra os principais deltas para auditoria.

## Automacao do Scheduler

O endpoint administrativo abaixo foi feito para o Cloud Scheduler:

```text
POST /automation/playoff-tick
Header: x-playoff-admin-secret: <PLAYOFF_ADMIN_SECRET>
```

Ele respeita `AUTOMATION_MIN_REFRESH_MINUTES`, atualiza jogos pela API externa apenas quando a janela minima passou, recalcula `/scores` somente quando ha fixture finalizada nova e avanca a chave quando a rodada atual do mata-mata estiver completa. Cada execucao grava auditoria em `/automation/playoffTick/runs`.

Cron recomendado para ficar bem abaixo do limite diario da API externa:

```text
*/30 * * * *
```

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
