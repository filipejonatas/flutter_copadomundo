# Plano de Performance e Cache

## Objetivo

Reduzir o cold start percebido no web e controlar o consumo da WC2026 API externa, que possui limite de 500 requisicoes por dia.

## Estado atual

- O frontend web esta publicado em Firebase Hosting.
- A API esta publicada em Cloud Run.
- `GET /matches/world-cup-2026` ja usa cache em memoria e cache persistente no Firebase Realtime Database.
- Quando existe cache persistente, a API responde o usuario com o cache e dispara refresh em background.
- O HAR v4 mostrou queda em `/matches/world-cup-2026` de cerca de 5.2s para cerca de 333ms.

## Plano futuro para economizar 500 req/dia

### 1. Separar leitura e refresh

Manter:

```text
GET /matches/world-cup-2026
```

Responsabilidade:

- Responder somente cache em memoria/Firebase.
- Nao chamar a WC2026 API externa no fluxo normal do usuario.
- Se cache nao existir, retornar erro controlado ou ultimo snapshot valido, conforme decisao de produto.

Criar:

```text
POST /internal/matches/refresh
```

Responsabilidade:

- Chamar a WC2026 API externa.
- Atualizar o cache em memoria.
- Atualizar o cache persistente em `cache/worldCup2026Matches`.

### 2. Proteger endpoint interno

Opcoes:

- Header secreto, por exemplo:

```text
X-Internal-Refresh-Key: <secret>
```

- Ou autenticacao IAM/OIDC do Cloud Scheduler para Cloud Run.

Preferencia para producao: OIDC/IAM quando possivel.

### 3. Agendar refresh controlado

Criar um Cloud Scheduler chamando:

```text
POST https://copa-palpite-api-486509842743.southamerica-east1.run.app/internal/matches/refresh
```

Frequencia inicial sugerida:

```text
*/15 * * * *
```

Resultado:

```text
4 chamadas/hora * 24h = 96 chamadas/dia
```

Isso fica bem abaixo do limite de 500 chamadas/dia.

### 4. Ajustar frequencia por contexto

Fora de jogos ao vivo:

```text
15 ou 30 minutos
```

Durante jogos ao vivo:

```text
1 ou 2 minutos
```

Apos o jogo:

```text
voltar para 15 ou 30 minutos
```

### 5. Evitar refresh paralelo

Adicionar lock no Firebase, por exemplo:

```text
cache/worldCup2026RefreshLock
```

O lock deve conter:

- `startedAt`
- `expiresAt`
- `instanceId` ou identificador do processo

Objetivo:

- Evitar que duas instancias Cloud Run chamem a WC2026 API externa ao mesmo tempo.
- Evitar desperdicio de requisicoes quando Scheduler, usuario e outros fluxos coincidirem.

### 6. Nao deixar fluxos de usuario consumir API externa

Estes fluxos devem usar apenas cache:

- `GET /matches/world-cup-2026`
- `GET /leaderboard`
- `GET /predictions/me`
- `POST /predictions`

Motivo:

- `leaderboard` e `savePrediction` usam `MatchesService`.
- Eles precisam de dados de jogos, mas nao devem ser responsaveis por atualizar a WC2026 API externa.

### 7. Logs e metricas

Registrar a cada refresh:

- horario de inicio
- duracao
- sucesso ou falha
- quantidade de jogos retornados
- origem do refresh
- erro resumido, se houver

Salvar tambem um contador diario aproximado:

```text
cache/worldCup2026Usage/yyyy-mm-dd
```

Campos sugeridos:

- `refreshCount`
- `lastRefreshAt`
- `lastSuccessAt`
- `lastFailureAt`

## Comandos uteis

Deploy do backend Cloud Run:

```powershell
& "C:\Users\JONATAS\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" run deploy copa-palpite-api --source api --region southamerica-east1 --allow-unauthenticated --project copa-palpite
```

Deploy do frontend Firebase Hosting:

```powershell
firebase deploy --only hosting --project copa-palpite
```

Se `firebase` nao estiver no PATH, usar:

```powershell
& "C:\Users\JONATAS\AppData\Roaming\npm\firebase.cmd" deploy --only hosting --project copa-palpite
```

Validar backend antes do deploy:

```powershell
cd api
npm.cmd run lint
npm.cmd run build
```

## PATH recomendado no Windows

Adicionar estes diretorios ao `Path` do usuario:

```text
C:\Users\JONATAS\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin
C:\Users\JONATAS\AppData\Roaming\npm
```

Depois reabrir o terminal e testar:

```powershell
gcloud --version
firebase --version
where gcloud
where firebase
```
