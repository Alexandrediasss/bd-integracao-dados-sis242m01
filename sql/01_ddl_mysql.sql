-- DDL corrigido para MySQL (testado no MySQL 8/9, engine InnoDB)
--
-- Mesmo modelo do sql/01_ddl_postgres.sql, com as adaptações de sintaxe:
--   * sem o schema "public." (no MySQL o banco faz o papel do schema);
--   * sem os casts do PostgreSQL ('...'::character varying);
--   * int8 -> BIGINT, int4 -> INT, float8 -> DOUBLE (mas usamos DECIMAL
--     para quantidades e valores, como no PostgreSQL);
--   * numeric(p, s) -> DECIMAL(p, s);
--   * ENGINE=InnoDB (necessário para chaves estrangeiras) e utf8mb4.
--
-- Uso:  CREATE DATABASE integracao; USE integracao;  e então rode este arquivo.

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE fornecedor (
    idfornecedor  VARCHAR(25)  NOT NULL,
    razao_social  VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produtos_filial (
    filial_id       INT            NOT NULL,
    produto_id      VARCHAR(25)    NOT NULL,
    descricao       VARCHAR(255)   NOT NULL,
    estoque         DECIMAL(12, 3) NOT NULL DEFAULT 0,
    preco_unitario  DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_compra    DECIMAL(12, 4) NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12, 4) NOT NULL DEFAULT 0,
    idfornecedor    VARCHAR(25)    NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id          BIGINT         NOT NULL,
    data_pedido        DATE           NULL,
    item               INT            NOT NULL,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    ordem_compra       BIGINT         NOT NULL DEFAULT 0,
    qtde_pedida        DECIMAL(12, 3) NULL,
    filial_id          INT            NULL,
    data_entrega       DATE           NULL,
    qtde_entregue      DECIMAL(12, 3) NOT NULL DEFAULT 0,
    qtde_pendente      DECIMAL(12, 3) NOT NULL DEFAULT 0,
    preco_compra       DECIMAL(12, 4) NULL DEFAULT 0,
    fornecedor_id      VARCHAR(25)    NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT pedido_compra_fornecedor_fk FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor (idfornecedor),
    INDEX idx_pedido_compra_ordem (ordem_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada       DATE           NULL,
    nro_nfe            VARCHAR(255)   NOT NULL,
    item               INT            NOT NULL,
    produto_id         VARCHAR(25)    NOT NULL,
    descricao_produto  VARCHAR(255)   NULL,
    ordem_compra       BIGINT         NOT NULL,
    qtde_recebida      DECIMAL(12, 3) NULL,
    filial_id          INT            NULL,
    custo_unitario     DECIMAL(12, 4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe),
    INDEX idx_entradas_ordem (ordem_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venda (
    venda_id        BIGINT         NOT NULL,
    data_emissao    DATE           NOT NULL,
    horariomov      TIME           NOT NULL DEFAULT '00:00:00',
    produto_id      VARCHAR(25)    NOT NULL,
    qtde_vendida    DECIMAL(12, 3) NULL,
    valor_unitario  DECIMAL(12, 4) NOT NULL DEFAULT 0,
    filial_id       BIGINT         NOT NULL DEFAULT 1,
    item            INT            NOT NULL DEFAULT 0,
    unidade_medida  VARCHAR(3)     NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX idx_venda_data (data_emissao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
