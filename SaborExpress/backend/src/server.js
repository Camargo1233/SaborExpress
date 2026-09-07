const app = require('./app');
const env = require('./config/env');
const db = require('./db');

const servidor = app.listen(env.porta, () => {
  console.log(`[SaborExpress] API ouvindo em http://localhost:${env.porta}/api (${env.nodeEnv})`);
});

/** Desligamento gracioso: para de aceitar conexoes e fecha o pool. */
async function encerrar(sinal) {
  console.log(`\n[SaborExpress] recebido ${sinal}, encerrando...`);
  servidor.close(async () => {
    await db.encerrar();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGINT', () => encerrar('SIGINT'));
process.on('SIGTERM', () => encerrar('SIGTERM'));

process.on('unhandledRejection', (motivo) => {
  console.error('[SaborExpress] promessa rejeitada sem tratamento:', motivo);
});

module.exports = servidor;
