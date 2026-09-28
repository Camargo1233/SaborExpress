const { Pool, types } = require('pg');
const env = require('../config/env');

// O driver pg devolve `numeric` como string para nao perder precisao.
// Como todo valor monetario aqui tem no maximo 2 casas e cabe com folga em
// um double, convertemos para Number na borda -- assim o JSON da API sai
// como 45.9 e nao "45.90", e o Flutter nao precisa fazer parse manual.
// Toda CONTA continua sendo feita no banco (numeric), nunca em JavaScript.
types.setTypeParser(1700, (valor) => (valor === null ? null : parseFloat(valor)));
types.setTypeParser(20, (valor) => (valor === null ? null : parseInt(valor, 10))); // bigint

const pool = new Pool({
  ...env.db,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

pool.on('error', (erro) => {
  console.error('[db] erro inesperado no pool de conexoes:', erro.message);
});

/** Consulta simples usando uma conexao do pool. */
async function query(texto, parametros) {
  return pool.query(texto, parametros);
}

/**
 * Executa varias operacoes dentro de UMA transacao.
 * Uso: await transacao(async (cliente) => { ... });
 * Qualquer excecao dispara ROLLBACK automatico.
 */
async function transacao(callback) {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const resultado = await callback(cliente);
    await cliente.query('COMMIT');
    return resultado;
  } catch (erro) {
    await cliente.query('ROLLBACK');
    throw erro;
  } finally {
    cliente.release();
  }
}

async function encerrar() {
  await pool.end();
}

module.exports = { pool, query, transacao, encerrar };
