/**
 * Aplica os arquivos .sql de database/migrations em ordem alfabetica e
 * registra o que ja rodou na tabela _migracoes -- assim rodar duas vezes
 * nao quebra nada.
 *
 *   npm run db:migrate          aplica o que falta
 *   npm run db:reset            derruba o schema e recria do zero
 */
const fs = require('fs');
const path = require('path');
const db = require('../src/db');

const PASTA = path.join(__dirname, '..', 'database', 'migrations');

async function garantirTabelaDeControle() {
  await db.query(`
    create table if not exists _migracoes (
      arquivo    text primary key,
      aplicada_em timestamptz not null default now()
    )
  `);
}

async function reset() {
  console.log('[migrate] --reset: derrubando o schema public...');
  await db.query('drop schema if exists public cascade');
  await db.query('create schema public authorization sabor_app');
}

async function principal() {
  const deveResetar = process.argv.includes('--reset');

  if (deveResetar) {
    await reset();
  }

  await garantirTabelaDeControle();

  const { rows } = await db.query('select arquivo from _migracoes');
  const jaAplicadas = new Set(rows.map((r) => r.arquivo));

  const arquivos = fs
    .readdirSync(PASTA)
    .filter((nome) => nome.endsWith('.sql'))
    .sort();

  let aplicadas = 0;

  for (const arquivo of arquivos) {
    if (jaAplicadas.has(arquivo)) {
      console.log(`[migrate] pulando ${arquivo} (ja aplicada)`);
      continue;
    }

    const sql = fs.readFileSync(
      path.join(PASTA, arquivo),
      'utf8'
    );

    console.log(`[migrate] aplicando ${arquivo}...`);

    await db.transacao(async (cliente) => {
      await cliente.query(sql);
      await cliente.query(
        'insert into _migracoes (arquivo) values ($1)',
        [arquivo]
      );
    });

    aplicadas += 1;
  }

  console.log(
    `[migrate] concluido. ${aplicadas} migracao(oes) aplicada(s).`
  );

  await db.encerrar();
}

principal().catch(async (erro) => {
  console.error('[migrate] falhou:', erro.message);
  await db.encerrar();
  process.exit(1);
});

