#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

loadEnvFile(path.resolve(process.cwd(), '.env'));
loadEnvFile(path.resolve(process.cwd(), 'api/.env'));

const options = parseArgs(process.argv.slice(2));
const apiBaseUrl = trimTrailingSlash(
  options.apiUrl ?? process.env.API_BASE_URL ?? process.env.PLAYOFF_API_BASE_URL ?? '',
);
const adminSecret = options.secret ?? process.env.PLAYOFF_ADMIN_SECRET ?? '';

if (!apiBaseUrl) {
  fail('Informe API_BASE_URL, PLAYOFF_API_BASE_URL ou --api-url.');
}

if (!adminSecret) {
  fail('Informe PLAYOFF_ADMIN_SECRET ou --secret.');
}

recalculate().catch((error) => {
  fail(error instanceof Error ? error.message : String(error));
});

async function recalculate() {
  const response = await fetch(`${apiBaseUrl}/leaderboard/recalculate`, {
    method: 'POST',
    headers: {
      'X-Playoff-Admin-Secret': adminSecret,
    },
  });
  const body = await response.text();

  if (!response.ok) {
    throw new Error(`API respondeu ${response.status}: ${body}`);
  }

  const result = body ? JSON.parse(body) : {};
  console.log(`Leaderboard recalculada para ${result.entriesCount ?? 0} jogador(es).`);
  console.log(`Jogos finalizados: ${result.finishedMatchesCount ?? 0}`);
  if (result.snapshotId) {
    console.log(`Snapshot anterior: scoreSnapshots/${result.snapshotId}`);
  }

  const deltas = Array.isArray(result.deltas) ? result.deltas : [];
  if (deltas.length > 0) {
    console.log('Principais alteracoes:');
    for (const delta of deltas.slice(0, 10)) {
      const sign = delta.delta > 0 ? '+' : '';
      console.log(
        `${delta.nick}: ${delta.previousPoints} -> ${delta.points} (${sign}${delta.delta})`,
      );
    }
  }
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    const [key, inlineValue] = value.split('=', 2);
    if (!key.startsWith('--')) continue;

    const normalizedKey = key.slice(2).replace(/-([a-z])/g, (_, letter) =>
      letter.toUpperCase(),
    );
    parsed[normalizedKey] = inlineValue ?? values[index + 1];
    if (inlineValue === undefined) index++;
  }
  return parsed;
}

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const separatorIndex = trimmed.indexOf('=');
    if (separatorIndex < 0) continue;

    const key = trimmed.slice(0, separatorIndex).trim();
    const value = trimmed
      .slice(separatorIndex + 1)
      .trim()
      .replace(/^['"]|['"]$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}

function trimTrailingSlash(value) {
  return value.trim().replace(/\/+$/, '');
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
