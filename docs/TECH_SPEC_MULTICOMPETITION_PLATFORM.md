# Tech Spec — Plataforma de Palpites Multicompetição

## 1. Status do documento

- **Status:** Proposta para implantação
- **Projeto de origem:** Copa Palpite / Copa do Mundo 2026
- **Projeto-alvo:** Novo repositório derivado, preparado para múltiplas competições e ligas privadas
- **Primeira competição sugerida:** UEFA Champions League
- **Fornecedor esportivo inicial:** Sportmicro Football API
- **Escopo deste documento:** arquitetura, modelo funcional, melhorias técnicas e plano de implantação
- **Fora de escopo:** implementação de código e redesign visual completo

## 2. Objetivo

Transformar a estrutura técnica já validada no Copa Palpite em uma plataforma reutilizável de palpites de futebol, capaz de suportar:

- diferentes competições e temporadas;
- ligas privadas criadas por usuários;
- adesão a ligas exclusivamente por convite;
- regras de pontuação configuráveis;
- fases de liga, grupos e mata-mata;
- confrontos de ida e volta, placar agregado, prorrogação e pênaltis;
- atualização automatizada e, quando necessário, em tempo real;
- crescimento sem leituras globais ou dependência direta do fornecedor no frontend.

O repositório atual deve ser preservado como produto de portfólio. A evolução descrita neste documento deve ocorrer em um novo repositório, preferencialmente mantendo o histórico Git até o ponto de derivação.

## 3. Princípios arquiteturais

1. **Domínio independente do fornecedor:** objetos da Sportmicro não serão usados diretamente como modelos da aplicação.
2. **Segredos somente no backend:** o Flutter nunca acessará a Sportmicro diretamente nem receberá sua API key.
3. **Backend como autoridade:** horários de fechamento, memberships, convites, pontuação e resultados serão validados no servidor.
4. **Dados particionados:** toda informação funcional será isolada por competição, temporada e liga quando aplicável.
5. **Processamento idempotente:** sincronizações, aceite de convite e cálculo de pontuação poderão ser repetidos sem duplicar efeitos.
6. **REST como reconciliação:** WebSockets aceleram atualizações, mas o estado definitivo será confirmado pela API REST.
7. **Observabilidade desde o início:** sincronizações, alterações de placar e cálculos críticos deverão ser auditáveis.
8. **MVP configurável, não genérico em excesso:** a primeira entrega pode atender somente à Champions League, mas sem nomes, datas ou regras específicas espalhadas pelo código.

## 4. Arquitetura-alvo

```text
Sportmicro REST API ─────────────┐
                                ├──> API NestJS / Ingestion Worker
Sportmicro WebSocket (opcional) ┘              │
                                               ├── normalização
                                               ├── cache
                                               ├── regras do domínio
                                               ├── pontuação
                                               └── auditoria
                                                        │
                                                        v
                                            Firebase Realtime Database
                                                        │
                                ┌───────────────────────┴──────────────────────┐
                                v                                              v
                     Flutter REST client                         Firebase realtime listeners
                  comandos e leituras estáveis                      eventos selecionados
```

### 4.1 Responsabilidades do Flutter

- autenticação do usuário;
- navegação e apresentação;
- criação e gestão de ligas permitida ao usuário;
- abertura, pré-visualização e aceite de convites;
- edição e envio de palpites;
- consumo de rankings e resultados;
- observação de snapshots em tempo real autorizados;
- cache local apenas para experiência de uso, nunca como fonte de verdade.

### 4.2 Responsabilidades da API NestJS

- autenticar Firebase ID Token e App Check;
- integrar com a Sportmicro;
- proteger a API key do fornecedor;
- normalizar competições, temporadas, rodadas, times e partidas;
- aplicar autorização por liga e papel;
- validar prazo e conteúdo dos palpites;
- criar, rotacionar, revogar e consumir convites;
- calcular ranking e pontuação;
- executar rotinas administrativas e de sincronização;
- registrar auditoria e métricas.

### 4.3 Responsabilidades do Firebase

- autenticação e App Check;
- persistência da aplicação;
- snapshots materializados para leitura eficiente;
- listeners em tempo real para estados selecionados;
- Storage para fotos controladas pela aplicação;
- regras restritivas, sem leitura global de dados privados.

## 5. Modelo de domínio

### 5.1 Entidades principais

#### Competition

Representa a competição, por exemplo UEFA Champions League.

Campos mínimos:

- `id`
- `name`
- `slug`
- `sport`
- `provider`
- `providerLeagueId`
- `activeSeasonId`
- `status`
- `createdAt`
- `updatedAt`

#### Season

Representa uma edição da competição.

- `id`
- `competitionId`
- `providerSeasonId`
- `name`
- `startsAt`
- `endsAt`
- `status`
- `syncState`

#### Stage e Round

Normalizam fases e rodadas do fornecedor.

- `id`
- `seasonId`
- `providerRoundId`
- `name`
- `type`: `qualifying`, `league`, `group`, `knockout`, `final` ou outro valor controlado
- `order`
- `startsAt`
- `endsAt`
- `metadata`

O sistema não deve inferir mata-mata por uma data fixa. O mapeamento `providerRoundId -> internalStageType` deverá ser persistido e ajustável administrativamente.

#### Team

- `id`
- `providerTeamId`
- `name`
- `shortName`
- `imageReference`
- `countryCode`

O uso de logos deverá respeitar direitos de propriedade intelectual. A UI deve possuir fallback sem imagem.

#### Fixture

- `id`
- `providerFixtureId`
- `competitionId`
- `seasonId`
- `stageId`
- `roundId`
- `tieId`, quando aplicável
- `previousLegFixtureId`, quando aplicável
- `leg`, quando aplicável
- `homeTeamId`
- `awayTeamId`
- `scheduledAt`
- `actualStartAt`
- `status`
- `statusReason`
- `score90`
- `scoreExtraTime`
- `scorePenalties`
- `aggregateScore`
- `qualifiedTeamId`
- `providerFetchedAt`
- `providerUpdatedAt`
- `normalizedAt`
- `payloadHash`

Estados internos sugeridos:

- `scheduled`
- `live`
- `paused`
- `finished`
- `postponed`
- `cancelled`
- `abandoned`
- `unknown`

#### League

Representa o bolão privado criado pelo usuário, não uma liga esportiva do fornecedor.

- `id`
- `name`
- `ownerUserId`
- `competitionId`
- `seasonId`
- `scoringRuleSetId`
- `status`
- `memberCount`
- `createdAt`
- `updatedAt`

No MVP, cada liga privada pertence a uma única competição e temporada.

#### LeagueMember

- `leagueId`
- `userId`
- `role`: `owner`, `admin` ou `member`
- `status`: `active`, `removed`, `blocked` ou `left`
- `joinedAt`
- `joinedByInviteId`
- `updatedAt`

#### Invitation

- `id`
- `leagueId`
- `createdBy`
- `tokenHash`
- `createdAt`
- `expiresAt`
- `revokedAt`
- `maxUses`
- `uses`
- `status`

O token em texto puro será apresentado somente na criação do link. Apenas seu hash será persistido.

#### Prediction

- `competitionId`
- `seasonId`
- `leagueId`
- `userId`
- `fixtureId`
- `homeScore`
- `awayScore`
- `qualifiedTeamId`, quando aplicável
- `submittedAt`
- `updatedAt`
- `version`

#### ScoringRuleSet

- `id`
- `name`
- `version`
- `exactScorePoints`
- `correctOutcomePoints`
- `correctGoalDifferencePoints`
- `qualifiedTeamPoints`
- `stageOverrides`
- `cutoffBufferSeconds`
- `createdAt`

Uma regra usada por uma temporada não deverá ser alterada retroativamente. Mudanças geram uma nova versão.

## 6. Estrutura de persistência sugerida

```text
competitions/{competitionId}
seasons/{seasonId}
stages/{seasonId}/{stageId}
fixtures/{seasonId}/{fixtureId}
teams/{teamId}

leagues/{leagueId}
leagueMembers/{leagueId}/{userId}
userLeagues/{userId}/{leagueId}

invitations/{inviteId}

predictions/{seasonId}/{leagueId}/{userId}/{fixtureId}
predictionsByFixture/{seasonId}/{leagueId}/{fixtureId}/{userId}

leaderboards/{seasonId}/{leagueId}/entries/{userId}
scoreEvents/{seasonId}/{leagueId}/{fixtureId}/{userId}

liveFixtures/{seasonId}/{fixtureId}
syncState/{provider}/{resourceId}
auditLogs/{category}/{logId}
```

`predictionsByFixture` é uma projeção para leitura eficiente. Ela evita percorrer todos os palpites de todos os usuários para calcular ou exibir o resultado de uma partida.

`userLeagues` também é uma projeção. Ela permite carregar as ligas do usuário sem consultar todas as memberships existentes.

## 7. Integração com a Sportmicro

### 7.1 Endpoints prioritários

O MVP deverá validar e utilizar somente o conjunto necessário:

- leagues;
- tournaments, se necessário para diferenciar subcompetições;
- seasons;
- seasons groups;
- seasons rounds;
- matches;
- matches live;
- standings;
- cup bracket;
- WebSocket de partidas, caso contratado e validado.

Odds, jogadores, notícias, escalações e estatísticas avançadas ficam fora do MVP.

### 7.2 Adaptador

Criar uma abstração conceitual `FootballDataProvider` com operações como:

- localizar competição;
- listar temporadas;
- obter estrutura da temporada;
- listar partidas paginadas;
- obter partidas ao vivo;
- obter classificação;
- obter chave eliminatória;
- abrir stream de eventos, quando disponível.

A implementação inicial será `SportmicroFootballProvider`. Nenhum serviço de pontuação ou tela poderá depender de nomes de campos da Sportmicro.

### 7.3 Paginação e sincronização

O endpoint de partidas possui paginação por `offset` e `limit`, com máximo documentado de 50 registros. A ingestão deve:

1. filtrar por temporada, torneio ou janela de datas;
2. percorrer todas as páginas;
3. validar cada payload;
4. normalizar a resposta;
5. comparar `payloadHash`;
6. gravar somente alterações;
7. registrar contagem, duração, páginas, quota e erros.

### 7.4 Estratégia de cache

| Recurso | Frequência inicial |
|---|---:|
| Competições e times | 1 a 7 dias |
| Temporadas | 6 a 24 horas |
| Fases, grupos e rodadas | 1 a 6 horas |
| Jogos distantes | 6 a 24 horas |
| Jogos nas próximas 48 horas | 15 a 60 minutos |
| Jogos próximos do início | 1 a 5 minutos |
| Jogos ao vivo | WebSocket ou até 10 segundos, conforme plano |
| Jogo recém-finalizado | confirmação REST após 1 a 5 minutos |
| Histórico finalizado | cache permanente, sujeito a reconciliação |

O fluxo comum do usuário nunca deve provocar chamadas diretas à Sportmicro.

### 7.5 WebSockets

O WebSocket da Sportmicro, se disponível no plano, será consumido por uma única camada controlada no backend. O Flutter continuará recebendo atualizações pelo Firebase.

Requisitos:

- conexão autenticada sem exposição da API key;
- filtro pelas competições relevantes;
- heartbeat e detecção de conexão interrompida;
- reconexão com backoff e jitter;
- deduplicação e ordenação defensiva de eventos;
- persistência de checkpoint;
- reconciliação REST após reconexão;
- circuit breaker para falhas repetidas;
- atualização somente de snapshots alterados.

WebSocket não será requisito para lançamento. O MVP poderá operar integralmente por sincronização REST.

### 7.6 Riscos do fornecedor

- disponibilidade e frequência de atualização podem variar por competição;
- cobertura anunciada deve ser validada no plano contratado;
- documentação apresenta inconsistências e páginas herdadas da marca SportDevs;
- valores de data, tempo ou status podem ser inesperados;
- preços e quotas precisam de confirmação contratual;
- logos e imagens não implicam licença automática de uso;
- resultados podem receber correções tardias.

Mitigações:

- schema validation;
- campos opcionais e estado `unknown`;
- cache persistente;
- auditoria de alterações;
- operação administrativa de correção e recálculo;
- adapter isolado;
- fallback visual para imagens;
- monitoramento de quota e opção pay-as-you-go desativada inicialmente.

## 8. Sistema de convite de liga

### 8.1 Fluxo

1. O fundador cria uma liga.
2. A API cria um convite e retorna um link contendo token aleatório forte.
3. O usuário abre `/invite/{token}`.
4. O app solicita uma pré-visualização segura da liga.
5. Se necessário, o usuário realiza login; o token permanece preservado.
6. O usuário confirma explicitamente a entrada.
7. A API valida token, expiração, revogação, limite de usos, bloqueios e membership existente.
8. Uma transação cria `leagueMembers` e `userLeagues` e incrementa o uso do convite.
9. A operação retorna sucesso idempotente se o usuário já for membro ativo.

Não haverá busca pública de ligas nem entrada por ID. A adesão ocorrerá somente pela abertura do link e confirmação do usuário.

### 8.2 Operações previstas

```text
POST /leagues
GET  /leagues/:leagueId
GET  /leagues/:leagueId/members
POST /leagues/:leagueId/invitations
POST /leagues/:leagueId/invitations/:inviteId/revoke
GET  /invitations/:token/preview
POST /invitations/:token/accept
```

### 8.3 Regras de autorização

- somente owner/admin cria ou revoga convites;
- somente membro ativo acessa dados privados da liga;
- owner não pode sair sem transferir propriedade ou encerrar a liga;
- usuário removido ou bloqueado pode ser impedido de reutilizar convites antigos;
- aceitar convite não concede privilégios administrativos;
- ações administrativas geram auditoria.

## 9. Palpites e pontuação

### 9.1 Fechamento de palpites

O backend valida:

- membership ativa;
- competição e temporada da liga;
- existência e estado da partida;
- placares dentro dos limites definidos;
- coerência entre placar e classificado;
- horário atual anterior a `scheduledAt - cutoffBufferSeconds`;
- versão para evitar sobrescrita concorrente acidental.

A UI pode mostrar contagem regressiva, mas não é autoridade.

### 9.2 Partidas adiadas

A política deverá ser escolhida e documentada antes do lançamento. Proposta inicial:

- adiamento identificado antes do cutoff: atualizar horário e manter edição aberta;
- adiamento identificado depois do cutoff: manter palpite bloqueado até decisão administrativa;
- cancelamento definitivo: excluir a partida da pontuação sem apagar o palpite histórico;
- alteração manual da política gera evento de auditoria.

### 9.3 Cálculo incremental

Quando uma partida chega a `finished` confirmado:

1. registrar versão do resultado;
2. carregar somente palpites daquela partida e liga;
3. calcular `scoreEvents` idempotentes;
4. aplicar deltas ao leaderboard;
5. atualizar posições materializadas;
6. publicar evento de ranking atualizado;
7. registrar métricas e auditoria.

O recálculo integral permanece disponível como rotina administrativa de recuperação e verificação.

Correções tardias do fornecedor devem gerar uma nova versão do resultado e recomputar apenas os eventos relacionados à partida.

## 10. Melhorias de código e performance

### 10.1 Backend

- substituir serviços específicos de Copa do Mundo por domínio genérico;
- separar ingestão, normalização, domínio e persistência;
- adotar DTOs e validação global;
- padronizar erros e códigos de resposta;
- reutilizar snapshots de partidas entre automação e recálculo;
- implementar locks distribuídos para sincronização e pontuação;
- tornar automações idempotentes;
- substituir rate limit em memória por gateway ou armazenamento compartilhado quando houver múltiplas instâncias;
- aplicar timeout, retry seletivo, backoff e circuit breaker;
- definir retenção de snapshots e logs;
- incluir backend no CI;
- adicionar testes de auth, cache, palpites, ranking, convites e concorrência.

### 10.2 Flutter

- organizar por funcionalidades: competitions, leagues, invitations, predictions, leaderboard e profile;
- consolidar Riverpod para estado assíncrono e compartilhado;
- compartilhar uma única fonte de partidas entre telas;
- criar cliente HTTP comum para Firebase Auth, App Check, timeout e erros;
- manter instância estável do router;
- retirar mocks do bootstrap de produção;
- implementar paginação real no backend;
- evitar chamadas repetidas ao alternar telas e rodadas;
- tratar estados `loading`, `refreshing`, `error`, `empty` e `data` consistentemente;
- medir rebuilds antes de micro-otimizações.

### 10.3 Banco

- eliminar leituras globais de usuários, scores e palpites;
- criar projeções por liga, usuário e partida;
- declarar índices necessários nas regras do Realtime Database;
- restringir ranking e palpites por membership;
- aplicar updates multipath ou transações nas projeções correlacionadas;
- monitorar bytes lidos/escritos e tamanho dos nós.

### 10.4 Web

- revisar política `no-cache` do bundle principal;
- validar versionamento e invalidação compatíveis com Flutter Web;
- usar cache longo apenas em assets versionados;
- medir cold start, bundle transferido, LCP e tempo até primeira interação.

## 11. Segurança e conformidade

- API key da Sportmicro armazenada no Secret Manager;
- credenciais diferentes por ambiente;
- Firebase ID Token e App Check em endpoints do app;
- IAM/OIDC para Scheduler e operações internas, quando possível;
- tokens de convite aleatórios e persistidos somente como hash;
- tokens e credenciais nunca registrados em logs;
- validação de autorização em toda operação de liga;
- rate limiting distribuído em endpoints de escrita e convite;
- proteção contra replay onde necessário;
- auditoria de mudanças de resultado, regras, membership e propriedade;
- revisão dos direitos de logos e imagens antes de publicação;
- política de privacidade e exclusão de conta/dados antes do lançamento público.

## 12. Observabilidade

### 12.1 Logs estruturados

Campos mínimos quando aplicáveis:

- `requestId`
- `provider`
- `competitionId`
- `seasonId`
- `leagueId`
- `fixtureId`
- `userId` anonimizado quando possível
- `operation`
- `durationMs`
- `result`
- `errorCode`

### 12.2 Métricas

- chamadas à Sportmicro por endpoint;
- quota restante, quando exposta;
- latência e taxa de erros do fornecedor;
- cache hit/miss;
- partidas sincronizadas e alteradas;
- atraso entre evento real e atualização local;
- conexões e reconexões WebSocket;
- palpites salvos e rejeitados;
- tempo de cálculo do ranking;
- convites criados, abertos, aceitos, expirados e revogados;
- leituras e escritas do Firebase.

### 12.3 Alertas

- ausência de sincronização bem-sucedida;
- quota próxima do limite;
- WebSocket desconectado por período prolongado;
- aumento de payloads inválidos;
- partida ao vivo sem atualização;
- cálculo de ranking com falha;
- divergência detectada em recálculo integral.

## 13. Estratégia de testes

### 13.1 Backend

- normalização de payloads reais e incompletos;
- paginação completa;
- cache e fallback;
- encerramento de palpite no limite;
- partidas adiadas, canceladas e corrigidas;
- placar normal, prorrogação, pênaltis e agregado;
- regras versionadas de pontuação;
- aceite simultâneo do mesmo convite;
- expiração, revogação e limite de usos;
- autorização por role e membership;
- idempotência de sincronização e score events;
- concorrência entre instâncias;
- autenticação e App Check;
- rate limiting.

### 13.2 Flutter

- preservação do convite durante login;
- criação e seleção de liga;
- palpites pendentes, salvos e encerrados;
- erros e retry;
- ranking e resultado detalhado;
- troca de competição/temporada;
- listeners em tempo real;
- responsividade Web e Android;
- acessibilidade básica.

### 13.3 Prova de contrato da Sportmicro

Validar com chave real:

- `league_id` correto da Champions;
- temporada atual;
- fases e rodadas;
- todas as partidas via paginação;
- UTC e offsets;
- confrontos de ida e volta;
- agregado, prorrogação e pênaltis;
- partidas adiadas e canceladas;
- standings e cup bracket;
- eventos e reconexão WebSocket;
- limites, quotas e headers de consumo;
- correções pós-jogo.

## 14. Plano de implantação por checkpoints

Cada checkpoint termina com critérios verificáveis. O próximo checkpoint só começa após o anterior estar aceito ou possuir riscos formalmente registrados.

### Checkpoint 0 — Derivação e isolamento

**Objetivo:** criar o novo produto sem afetar o repositório de portfólio.

Entregas:

- novo repositório com histórico preservado;
- novo nome técnico e identidade provisória;
- novo projeto Firebase;
- novo serviço Cloud Run;
- ambientes local, staging e produção definidos;
- credenciais e secrets separados;
- README explicando a derivação.

Critérios de conclusão:

- nenhum recurso do Copa Palpite é compartilhado com o novo app;
- build Flutter e API executam no novo repositório;
- CI básico está verde para Flutter e NestJS.

### Checkpoint 1 — Spike da Sportmicro

**Objetivo:** validar o fornecedor antes de acoplar o produto.

Entregas:

- conta e plano de teste;
- relatório de cobertura da Champions;
- respostas reais anonimizadas para testes de contrato;
- medição de quota, latência e paginação;
- validação de rounds, partidas, agregado e pênaltis;
- teste de WebSocket, se disponível;
- decisão registrada: aprovar, aprovar com ressalvas ou rejeitar.

Critérios de conclusão:

- uma temporada pode ser reconstruída integralmente;
- casos de ida e volta e decisão por pênaltis são interpretados corretamente;
- custo projetado e limites são conhecidos;
- termos de uso e imagens foram revisados.

### Checkpoint 2 — Domínio genérico e adaptador

**Objetivo:** remover acoplamento estrutural à Copa de 2026.

Entregas:

- entidades Competition, Season, Stage, Round, Team e Fixture;
- interface FootballDataProvider;
- SportmicroFootballProvider;
- normalização e schema validation;
- estados internos de partida;
- configuração inicial da Champions.

Critérios de conclusão:

- nenhum serviço de domínio depende de campos da Sportmicro;
- não há datas fixas para identificar fases;
- fixtures reais são normalizadas e persistidas;
- payloads inválidos são rejeitados com log seguro.

### Checkpoint 3 — Pipeline de sincronização e cache

**Objetivo:** manter calendário e resultados locais com consumo controlado.

Entregas:

- sincronização paginada;
- cache persistente;
- Scheduler protegido por IAM/OIDC ou equivalente;
- lock distribuído;
- hash e escrita somente em alterações;
- estado de sincronização e auditoria;
- fallback para último snapshot válido.

Critérios de conclusão:

- fluxos de usuário não chamam a Sportmicro;
- duas instâncias não executam refresh externo simultâneo;
- falha externa não remove dados válidos;
- consumo diário permanece dentro do orçamento definido.

### Checkpoint 4 — Ligas privadas e memberships

**Objetivo:** permitir criação e isolamento de bolões.

Entregas:

- criação de liga;
- owner, admin e member;
- índices `leagueMembers` e `userLeagues`;
- regras de autorização;
- listagem das ligas do usuário;
- transferência de propriedade e saída controlada.

Critérios de conclusão:

- usuário não membro não lê dados privados;
- membership é a fonte de autorização;
- não existem buscas globais para carregar ligas do usuário.

### Checkpoint 5 — Convites por link

**Objetivo:** garantir adesão somente após abertura e aceite do convite.

Entregas:

- criação, preview, aceite e revogação;
- token forte e hash persistido;
- expiração e limite de uso;
- preservação do token durante login;
- aceite transacional e idempotente;
- auditoria e métricas.

Critérios de conclusão:

- não existe entrada sem token válido;
- uso simultâneo respeita limite de usos;
- refresh ou clique repetido não duplica membership;
- convite revogado ou expirado é recusado.

### Checkpoint 6 — Palpites configuráveis

**Objetivo:** registrar palpites por temporada e liga com segurança.

Entregas:

- ScoringRuleSet versionado;
- criação e edição de palpites;
- suporte a classificado no mata-mata;
- cutoff no servidor;
- política de partidas adiadas;
- índices por usuário e fixture;
- feedback consistente no Flutter.

Critérios de conclusão:

- palpites não podem ser alterados após cutoff;
- uma liga não acessa palpites de outra;
- ida, volta, agregado e classificado estão cobertos por testes;
- edição concorrente não causa perda silenciosa.

### Checkpoint 7 — Pontuação e leaderboard incremental

**Objetivo:** calcular rankings sem leituras globais.

Entregas:

- score events idempotentes;
- atualização incremental por partida;
- leaderboard materializado por liga;
- correção e recálculo por fixture;
- recálculo integral administrativo;
- histórico explicável de pontos.

Critérios de conclusão:

- finalizar uma partida processa apenas palpites relacionados;
- reprocessar o mesmo resultado não duplica pontos;
- correção tardia produz ranking correto e auditável;
- recálculo integral coincide com o incremental.

### Checkpoint 8 — Tempo real controlado

**Objetivo:** atualizar placares e ranking sem polling excessivo.

Entregas:

- listeners Firebase para fixtures relevantes;
- ingestão WebSocket opcional no backend;
- reconexão e reconciliação REST;
- snapshots compactos;
- sinalização de dado provisório e confirmado.

Critérios de conclusão:

- nenhuma API key aparece no cliente;
- perda da conexão não corrompe estado;
- REST reconcilia eventos perdidos;
- custo de conexões e Firebase foi medido.

### Checkpoint 9 — Hardening e observabilidade

**Objetivo:** preparar staging para operação confiável.

Entregas:

- logs estruturados;
- dashboards e alertas;
- rate limit distribuído;
- política de retenção;
- testes de concorrência e falhas;
- revisão de regras Firebase;
- CI completo e cobertura mínima acordada;
- runbooks de sincronização, resultado incorreto e recálculo.

Critérios de conclusão:

- falhas críticas geram alerta;
- operações administrativas são auditadas;
- staging passa por teste de carga proporcional à meta inicial;
- não há leitura/escrita global desnecessária.

### Checkpoint 10 — UX/UI e lançamento

**Objetivo:** entregar uma experiência utilizável e mensurável.

Entregas:

- onboarding por convite;
- seletor de liga e competição;
- pendências de palpites na home;
- filtros por pendente, ao vivo e encerrado;
- feedback de salvamento;
- histórico de pontuação;
- acessibilidade básica;
- responsividade Web e Android;
- analytics de funil sem dados sensíveis.

Critérios de conclusão:

- convite aberto antes do login chega ao aceite após autenticação;
- usuário identifica palpites pendentes e status de salvamento;
- fluxos principais passam em testes de integração;
- métricas de ativação e erros estão disponíveis.

### Checkpoint 11 — Produção gradual

**Objetivo:** reduzir risco do lançamento.

Entregas:

- piloto fechado com poucas ligas;
- limites conservadores de usuários e convites;
- monitoramento diário da Sportmicro e Firebase;
- processo de suporte e correção;
- expansão gradual após estabilidade.

Critérios de conclusão:

- uma rodada real foi processada ponta a ponta;
- rankings foram conferidos por recálculo independente;
- nenhuma falha crítica permanece aberta;
- quota e custo real estão dentro da projeção.

## 15. Priorização

### Obrigatório para MVP

- domínio de competição e temporada;
- Sportmicro via backend;
- sincronização REST e cache;
- ligas privadas;
- convites por link;
- palpites e cutoff no servidor;
- pontuação incremental;
- ranking por liga;
- auditoria mínima;
- Web e Android funcionais.

### Pós-MVP

- WebSocket da Sportmicro;
- ranking provisório ao vivo;
- múltiplas competições simultâneas;
- comunidades reunindo várias ligas;
- notificações push;
- chat;
- estatísticas e odds;
- redesign visual avançado;
- personalização de regras pelo fundador.

## 16. Decisões pendentes

Antes da implantação devem ser decididos:

1. nome e identidade do novo produto;
2. plano Sportmicro e limites contratados;
3. política de partida adiada;
4. regras exatas de pontuação da Champions;
5. visibilidade de palpites de outros membros antes/depois do jogo;
6. validade e número máximo de usos de convites;
7. limite inicial de membros por liga;
8. possibilidade de usuário participar de múltiplas ligas com o mesmo palpite ou palpites independentes;
9. suporte a liga pública no futuro;
10. uso ou não de logos fornecidos pelo fornecedor.

## 17. Critério global de sucesso

A implantação será considerada bem-sucedida quando um usuário puder:

1. abrir um link de convite;
2. autenticar-se sem perder o convite;
3. aderir à liga;
4. registrar palpites da Champions antes do cutoff;
5. acompanhar resultados atualizados;
6. receber pontuação correta após o encerramento;
7. consultar um ranking isolado e auditável da sua liga;

e quando o sistema conseguir executar esse fluxo sem expor a Sportmicro ao cliente, sem leituras globais do banco e sem duplicar efeitos após retries ou correções de resultado.
