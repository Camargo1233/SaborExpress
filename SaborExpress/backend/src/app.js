const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const env = require('./config/env');
const rotas = require('./routes');
const { naoEncontrado, tratarErro } = require('./middlewares/erro');

const app = express();

// Cabecalhos de seguranca (XSS, clickjacking, sniffing...)
app.use(helmet());

// RN-SEG-007: em producao so as origens declaradas acessam a API.
app.use(
  cors({
    origin(origem, callback) {
      if (!origem) return callback(null, true); // apps mobile e curl
      if (!env.ehProducao) return callback(null, true);
      if (env.corsOrigins.includes(origem)) return callback(null, true);
      return callback(new Error(`Origem nao permitida pelo CORS: ${origem}`));
    },
    credentials: true,
  })
);

app.use(express.json({ limit: '1mb' }));

if (env.nodeEnv !== 'test') {
  app.use(morgan(env.ehProducao ? 'combined' : 'dev'));
}

// Limite geral de requisicoes por IP (defesa basica contra abuso).
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 300,
    standardHeaders: true,
    legacyHeaders: false,
    message: { erro: 'Muitas requisicoes. Aguarde um instante.' },
  })
);

app.use('/api', rotas);

app.use(naoEncontrado);
app.use(tratarErro);

module.exports = app;
