# Copa Palpite

Aplicação full stack de palpites para a Copa do Mundo de 2026, disponível para Web e Android. O projeto reúne autenticação, calendário de jogos, registro de palpites, resultados, ranking e um playoff eliminatório com 32 participantes.

**Aplicação:** [copa-palpite.web.app](https://copa-palpite.web.app)

## Funcionalidades

- Login com Google por meio do Firebase Authentication.
- Proteção de acesso com Firebase App Check.
- Lista de partidas e seleção por rodada.
- Registro e atualização de palpites antes do início dos jogos.
- Resultados e pontuação dos participantes.
- Ranking geral persistido e auditável.
- Playoff de 32 jogadores, com chaveamento, confrontos e avanço por rodada.
- Perfil com apelido e avatar personalizado.
- Layout responsivo para Web e Android.
- Rotina automatizada para atualizar partidas, recalcular pontos e avançar o playoff.

## Arquitetura e tecnologias

### Front-end

- Flutter e Dart
- Riverpod para gerenciamento de estado
- GoRouter para navegação
- Firebase Authentication, Realtime Database, Storage e App Check

### Back-end

- NestJS e TypeScript
- Firebase Admin SDK
- Integração com a API de partidas da Copa de 2026
- API hospedada no Google Cloud Run
- Automação compatível com Google Cloud Scheduler

### Qualidade e entrega

- Testes unitários, de widgets, integração e golden tests
- Análise estática e formatação automatizadas
- Pipeline de CI no GitHub Actions
- Front-end publicado no Firebase Hosting

## Pré-requisitos

- Flutter compatível com Dart `^3.9.0`
- Node.js e npm
- Firebase CLI
- Um projeto Firebase configurado

## Configuração

Crie um `.env` na raiz a partir de `.env.example`:

```env
API_BASE_URL=https://sua-api-do-cloud-run.run.app
APP_CHECK_WEB_RECAPTCHA_SITE_KEY=sua-chave-recaptcha-v3
APP_CHECK_ANDROID_PROVIDER=play_integrity
```

As variáveis e instruções específicas do servidor estão documentadas em [`api/README.md`](api/README.md). Não versione arquivos `.env`, credenciais de serviço, keystores ou chaves privadas.

## Execução local

Para iniciar o back-end e o Flutter Web juntos no Windows:

```powershell
.\scripts\run-local.ps1
```

Serviços iniciados:

```text
API:         http://127.0.0.1:3000
Flutter Web: http://127.0.0.1:4200
```

Para executar somente o front-end Web:

```powershell
.\scripts\run-web.ps1
```

Para usar `localhost` como origem:

```powershell
.\scripts\run-web.ps1 -HostName localhost
```

## Android

Execute em um dispositivo ou emulador conectado:

```powershell
.\scripts\run-android.ps1
```

Se houver mais de um dispositivo:

```powershell
flutter devices
.\scripts\run-android.ps1 -DeviceId "emulator-5554"
```

Gere um APK de produção:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-em-producao"
```

Para gerar um Android App Bundle:

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl "https://sua-api-em-producao" -Target appbundle
```

O App Check usa Play Integrity em produção. O provider `debug` deve ser utilizado apenas em diagnósticos locais com o token devidamente registrado no Firebase.

## Testes e análise

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Build e publicação Web

O script lê as configurações do `.env` e gera o conteúdo em `build/web`:

```powershell
.\scripts\build-web-release.ps1
```

Publique somente o front-end no Firebase Hosting:

```powershell
firebase deploy --only hosting --project copa-palpite
```

As regras do Realtime Database e do Storage devem ser publicadas separadamente quando forem alteradas.

## Estrutura principal

```text
api/                 API NestJS e automações
assets/              Imagens, ícones e bandeiras
integration_test/    Testes de fluxo
lib/                 Aplicação Flutter
scripts/             Execução, build e rotinas administrativas
test/                Testes unitários, de widgets e golden tests
web/                 Configuração da aplicação Web
```

## Segurança

O repositório contém somente arquivos-modelo de configuração. Segredos administrativos, chaves da API externa, credenciais Firebase e assinatura Android devem permanecer fora do controle de versão.
