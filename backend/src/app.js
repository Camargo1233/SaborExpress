const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

const env = require('./config/env');
const rotas = require('./routes');
const { naoEncontrado, tratarErro } = require('./middlewares/erro');

const app = express();

// Cabecalhos de seguranca (XSS, clickjacking, sniffing...)
app.use(
  helmet({
    crossOriginResourcePolicy: {
      policy: 'cross-origin',
    },
  })
);

// RN-SEG-007: em producao so as origens declaradas acessam a API.
app.use(
  cors({
    origin(origem, callback) {
      if (!origem) return callback(null, true); // apps mobile e curl
      if (!env.ehProducao) return callback(null, true);
      if (env.corsOrigins.includes(origem)) return callback(null, true);

      return callback(
        new Error(`Origem nao permitida pelo CORS: ${origem}`)
      );
    },
    credentials: true,
  })
);

app.use(express.json({ limit: '1mb' }));

// ============================================================
// IMAGENS PUBLICAS
// ============================================================
//
// Os arquivos enviados pelo gerente ficarao em:
//
// backend/uploads/produtos/
//
// E poderao ser acessados por:
//
// http://localhost:3000/uploads/produtos/nome-da-imagem.jpg
//
// Isso permite que gerente, cliente e garcom utilizem a mesma
// imagem salva pelo backend.
//
app.use(
  '/uploads',
  express.static(path.join(__dirname, '..', 'uploads'))
);

if (env.nodeEnv !== 'test') {
  app.use(morgan(env.ehProducao ? 'combined' : 'dev'));
}

// Limite geral de requisicoes por IP.
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 300,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      erro: 'Muitas requisicoes. Aguarde um instante.',
    },
  })
);

// ============================================================
// ROTAS DA API
// ============================================================

app.use('/api', rotas);

// ============================================================
// TRATAMENTO DE ERROS
// ============================================================

app.use(naoEncontrado);
app.use(tratarErro);

module.exports = app;