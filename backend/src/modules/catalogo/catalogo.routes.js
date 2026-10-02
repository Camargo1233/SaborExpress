const { Router } = require('express');
const { z } = require('zod');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const servico = require('./catalogo.service');
const validar = require('../../middlewares/validar');
const {
  autenticar,
  autenticarOpcional,
} = require('../../middlewares/autenticar');
const {
  exigirPerfil,
  carregarPerfilSeHouver,
} = require('../../middlewares/restaurante');

// mergeParams: precisamos do :restauranteId definido no router pai.
const rotas = Router({ mergeParams: true });

// ============================================================
// CONFIGURACAO DO UPLOAD DE IMAGENS
// ============================================================

const pastaUploads = path.join(
  __dirname,
  '..',
  '..',
  '..',
  'uploads',
  'produtos'
);

// Garante que a pasta exista.
fs.mkdirSync(pastaUploads, { recursive: true });

const armazenamento = multer.diskStorage({
  destination: (req, file, callback) => {
    callback(null, pastaUploads);
  },

  filename: (req, file, callback) => {
    const extensaoOriginal = path.extname(file.originalname).toLowerCase();

    const extensoesPermitidas = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
    ];

    const extensao = extensoesPermitidas.includes(extensaoOriginal)
      ? extensaoOriginal
      : '.jpg';

    const nomeArquivo = `${Date.now()}-${crypto.randomUUID()}${extensao}`;

    callback(null, nomeArquivo);
  },
});

const uploadImagem = multer({
  storage: armazenamento,

  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB
  },

  fileFilter: (req, file, callback) => {
    const extensao = path.extname(file.originalname).toLowerCase();

    const extensoesPermitidas = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
    ];

    if (!extensoesPermitidas.includes(extensao)) {
      return callback(
        new Error(
          'Formato de imagem nao permitido. Use JPG, JPEG, PNG ou WEBP.'
        )
      );
    }

    callback(null, true);
  },
});

// ============================================================
// SCHEMAS
// ============================================================

const schemaCategoria = z.object({
  nome: z.string().trim().min(2).max(80),
  descricao: z.string().trim().max(500).optional(),
  ordem: z.number().int().min(0).optional(),
});

const schemaCategoriaEdicao = schemaCategoria.partial().extend({
  ativo: z.boolean().optional(),
});

const schemaProduto = z.object({
  nome: z.string().trim().min(2).max(120),

  descricao: z
    .string()
    .trim()
    .max(1000)
    .optional(),

  preco: z
    .number()
    .positive('O preco deve ser maior que zero.')
    .max(99999.99),

  categoriaId: z
    .string()
    .uuid()
    .optional(),

  imagemUrl: z
    .string()
    .url()
    .max(2000)
    .optional(),

  tempoPreparoMin: z
    .number()
    .int()
    .min(0)
    .max(600)
    .optional(),

  destaque: z
    .boolean()
    .optional(),

  disponivel: z
    .boolean()
    .optional(),
});

const schemaProdutoEdicao = schemaProduto.partial().extend({
  ativo: z.boolean().optional(),
});

const schemaFiltroProdutos = z.object({
  categoriaId: z
    .string()
    .uuid()
    .optional(),

  busca: z
    .string()
    .trim()
    .min(1)
    .max(80)
    .optional(),

  destaque: z
    .enum(['true', 'false'])
    .optional(),
});

// ============================================================
// FUNCOES AUXILIARES
// ============================================================

function montarUrlImagem(req, nomeArquivo) {
  return `${req.protocol}://${req.get('host')}/uploads/produtos/${nomeArquivo}`;
}

function converterBoolean(valor) {
  if (valor === undefined) {
    return undefined;
  }

  if (typeof valor === 'boolean') {
    return valor;
  }

  return String(valor).toLowerCase() === 'true';
}

function converterNumero(valor) {
  if (
    valor === undefined ||
    valor === null ||
    valor === ''
  ) {
    return undefined;
  }

  return Number(valor);
}

// ============================================================
// CATEGORIAS
// ============================================================

rotas.get(
  '/categorias',
  autenticarOpcional,
  carregarPerfilSeHouver,
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.listarCategorias(
          req.restaurante,
          Boolean(req.perfil)
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.post(
  '/categorias',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaCategoria),
  async (req, res, proximo) => {
    try {
      res
        .status(201)
        .json(
          await servico.criarCategoria(
            req.restaurante,
            req.body
          )
        );
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.patch(
  '/categorias/:categoriaId',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaCategoriaEdicao),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.atualizarCategoria(
          req.restaurante,
          req.params.categoriaId,
          req.body
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// PRODUTOS - LISTAGEM
// ============================================================

rotas.get(
  '/produtos',
  autenticarOpcional,
  carregarPerfilSeHouver,
  validar(schemaFiltroProdutos, 'query'),
  async (req, res, proximo) => {
    try {
      const filtros = {
        ...req.query,
        destaque: req.query.destaque === 'true',
      };

      res.json(
        await servico.listarProdutos(
          req.restaurante,
          filtros,
          Boolean(req.perfil)
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

rotas.get(
  '/produtos/:produtoId',
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.buscarProduto(
          req.restaurante,
          req.params.produtoId
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// UPLOAD DE IMAGEM
// ============================================================
//
// Flutter envia:
//
// multipart/form-data
//
// campo:
// imagem
//
// Retorno:
//
// {
//   "imagemUrl":
//   "http://localhost:3000/uploads/produtos/arquivo.jpg"
// }
//

rotas.post(
  '/produtos/upload-imagem',
  autenticar,
  exigirPerfil('gerente'),
  (req, res, proximo) => {
    uploadImagem.single('imagem')(req, res, (erro) => {
      if (erro) {
        console.error('[UPLOAD IMAGEM] Erro do Multer:', erro);

        return res.status(500).json({
          erro: erro.message,
          codigo: erro.code || null,
        });
      }

      proximo();
    });
  },
  async (req, res, proximo) => {
    try {
      console.log('[UPLOAD IMAGEM] Arquivo recebido:', req.file);

      if (!req.file) {
        return res.status(400).json({
          erro: 'Nenhuma imagem foi enviada.',
        });
      }

      const imagemUrl = montarUrlImagem(
        req,
        req.file.filename,
      );

      console.log('[UPLOAD IMAGEM] URL criada:', imagemUrl);

      return res.status(201).json({
        imagemUrl,
      });
    } catch (erro) {
      console.error('[UPLOAD IMAGEM] Erro:', erro);
      proximo(erro);
    }
  }
);

// ============================================================
// CRIAR PRODUTO
// ============================================================

rotas.post(
  '/produtos',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaProduto),
  async (req, res, proximo) => {
    try {
      res
        .status(201)
        .json(
          await servico.criarProduto(
            req.restaurante,
            req.body
          )
        );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// ATUALIZAR PRODUTO
// ============================================================

rotas.patch(
  '/produtos/:produtoId',
  autenticar,
  exigirPerfil('gerente'),
  validar(schemaProdutoEdicao),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.atualizarProduto(
          req.restaurante,
          req.params.produtoId,
          req.body
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// DISPONIBILIDADE
// ============================================================

// Garcom e cozinha podem marcar "acabou" sem poder editar preco.
rotas.patch(
  '/produtos/:produtoId/disponibilidade',
  autenticar,
  exigirPerfil(
    'gerente',
    'garcom',
    'cozinha'
  ),
  validar(
    z.object({
      disponivel: z.boolean(),
    })
  ),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.atualizarProduto(
          req.restaurante,
          req.params.produtoId,
          {
            disponivel:
              req.body.disponivel,
          }
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

// ============================================================
// DESATIVAR PRODUTO
// ============================================================

rotas.delete(
  '/produtos/:produtoId',
  autenticar,
  exigirPerfil('gerente'),
  async (req, res, proximo) => {
    try {
      res.json(
        await servico.desativarProduto(
          req.restaurante,
          req.params.produtoId
        )
      );
    } catch (erro) {
      proximo(erro);
    }
  }
);

module.exports = rotas;