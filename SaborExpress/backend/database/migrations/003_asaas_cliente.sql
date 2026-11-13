
-- Adiciona o identificador do cliente no Asaas.
-- Preserva todos os usuarios existentes.

ALTER TABLE usuarios
ADD COLUMN IF NOT EXISTS asaas_cliente_id VARCHAR(100);

-- Evita associar o mesmo cadastro Asaas
-- a mais de um usuario local.

CREATE UNIQUE INDEX IF NOT EXISTS
idx_usuarios_asaas_cliente_id
ON usuarios (asaas_cliente_id);


-- Adiciona o status de pedido enviado
-- que aguarda a confirmação do gerente.

ALTER TYPE pedido_status
ADD VALUE IF NOT EXISTS 'aguardando_confirmacao';