#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

loadEnvFile(path.resolve(process.cwd(), '.env'));
loadEnvFile(path.resolve(process.cwd(), 'api/.env'));

const args = process.argv.slice(2);
const options = parseArgs(args);
const round = options.round ?? args.find((arg) => !arg.startsWith('--')) ?? 'round_of_32';
const apiBaseUrl = trimTrailingSlash(
  options.apiUrl ?? process.env.API_BASE_URL ?? process.env.PLAYOFF_API_BASE_URL ?? '',
);
const adminSecret = options.secret ?? process.env.PLAYOFF_ADMIN_SECRET ?? '';
const force = options.force === true;

if (!apiBaseUrl) {
  fail('Informe API_BASE_URL, PLAYOFF_API_BASE_URL ou --api-url.');
}

if (!adminSecret) {
  fail('Informe PLAYOFF_ADMIN_SECRET ou --secret.');
}

advanceRound().catch((error) => {
  fail(error instanceof Error ? error.message : String(error));
});

async function advanceRound() {
  const response = await fetch(`${apiBaseUrl}/playoffs/current/advance-round`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Playoff-Admin-Secret': adminSecret,
    },
    body: JSON.stringify({ round, force }),
  });
  const body = await response.text();

  if (!response.ok) {
    throw new Error(`API respondeu ${response.status}: ${body}`);
  }

  const bracket = body ? JSON.parse(body) : {};
  const matches = Array.isArray(bracket.matches) ? bracket.matches : [];
  const advanced = matches.filter(
    (match) => normalizeRound(match.round) === normalizeRound(round) && match.winnerParticipantId,
  );

  console.log(`Rodada ${round} atualizada com ${advanced.length} vencedor(es).`);
  console.log(`Bracket: ${bracket.id ?? 'current'}`);
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (value === '--force') {
      parsed.force = true;
      continue;
    }

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

function normalizeRound(roundValue) {
  return String(roundValue ?? '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
}

function trimTrailingSlash(value) {
  return value.trim().replace(/\/+$/, '');
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
