require('dotenv').config({ quiet: true });

/**
 * Centraliza a leitura de variaveis de ambiente e falha rapido (fail fast)
 * quando algo obrigatorio esta faltando. Evita o app subir "meio configurado".
 */
function obrigatoria(nome, padraoDev) {
  const valor = process.env[nome];
  if (valor) return valor;
  if (padraoDev && process.env.NODE_ENV !== 'production') return padraoDev;
  throw new Error(`Variavel de ambiente obrigatoria ausente: ${nome}`);
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  porta: Number(process.env.PORT || 3000),

  db: {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'sabor_express',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  },

  jwt: {
    secret: obrigatoria('JWT_SECRET', 'segredo-apenas-para-desenvolvimento'),
    expiresIn: process.env.JWT_EXPIRES_IN || '8h',
  },

  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),
};

env.ehProducao = env.nodeEnv === 'production';

if (env.ehProducao && env.jwt.secret.length < 32) {
  throw new Error('JWT_SECRET precisa ter no minimo 32 caracteres em producao.');
}

module.exports = env;
