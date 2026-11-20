-- DDL corrigido para PostgreSQL
-- Testado no PostgreSQL 17.
--
-- Principais correções em relação ao sql/01_ddl_enunciado.sql
-- (lista completa em docs/parte1_importacao.md):
--   * entradas_mercadoria: faltava a coluna ordem_compra, usada na PK e no
--     vínculo com pedido_compra.
--   * produtos_filial: faltava vírgula antes do CONSTRAINT; PK citava idproduto
--     (coluna inexistente); nomes com erro de digitação (decricao, idfonecedor);
--     filial_id aceitava NULL sendo parte da PK.
--   * fornecedor: nome com erro de digitação (idforncedor); PK citava idproduto,
--     que não existe nem faz sentido nessa tabela.
--   * Tipos padronizados: produto_id sempre varchar(25); código do fornecedor
--     sempre varchar(25); chaves e itens inteiros em vez de float8;
--     quantidades e valores em numeric em vez de float8 (sem erro de
--     arredondamento em somas de R$).
--   * Chaves estrangeiras para fornecedor (produtos_filial e pedido_compra).
--   * Tabelas criadas na ordem das dependências.

DROP TABLE IF EXISTS public.venda;
DROP TABLE IF EXISTS public.entradas_mercadoria;
DROP TABLE IF EXISTS public.pedido_compra;
DROP TABLE IF EXISTS public.produtos_filial;
DROP TABLE IF EXISTS public.fornecedor;

CREATE TABLE public.fornecedor (
    idfornecedor  varchar(25)  NOT NULL,
    razao_social  varchar(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
);

CREATE TABLE public.produtos_filial (
    filial_id       int4           NOT NULL,
    produto_id      varchar(25)    NOT NULL,
    descricao       varchar(255)   NOT NULL,
    estoque         numeric(12, 3) DEFAULT 0 NOT NULL,
    preco_unitario  numeric(12, 4) DEFAULT 0 NOT NULL,
    preco_compra    numeric(12, 4) DEFAULT 0 NOT NULL,
    preco_venda     numeric(12, 4) DEFAULT 0 NOT NULL,
    idfornecedor    varchar(25)    NULL,
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES public.fornecedor (idfornecedor)
);

CREATE TABLE public.pedido_compra (
    pedido_id          int8           NOT NULL,
    data_pedido        date           NULL,
    item               int4           NOT NULL,
    produto_id         varchar(25)    NOT NULL,
    descricao_produto  varchar(255)   NULL,
    ordem_compra       int8           DEFAULT 0 NOT NULL,
    qtde_pedida        numeric(12, 3) NULL,
    filial_id          int4           NULL,
    data_entrega       date           NULL,
    qtde_entregue      numeric(12, 3) DEFAULT 0 NOT NULL,
    qtde_pendente      numeric(12, 3) DEFAULT 0 NOT NULL,
    preco_compra       numeric(12, 4) DEFAULT 0 NULL,
    fornecedor_id      varchar(25)    NULL,
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT pedido_compra_fornecedor_fk FOREIGN KEY (fornecedor_id)
        REFERENCES public.fornecedor (idfornecedor)
);

CREATE TABLE public.entradas_mercadoria (
    data_entrada       date           NULL,
    nro_nfe            varchar(255)   NOT NULL,
    item               int4           NOT NULL,
    produto_id         varchar(25)    NOT NULL,
    descricao_produto  varchar(255)   NULL,
    ordem_compra       int8           NOT NULL,
    qtde_recebida      numeric(12, 3) NULL,
    filial_id          int4           NULL,
    custo_unitario     numeric(12, 4) DEFAULT 0 NOT NULL,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE public.venda (
    venda_id        int8           NOT NULL,
    data_emissao    date           NOT NULL,
    horariomov      time           DEFAULT '00:00:00' NOT NULL,
    produto_id      varchar(25)    NOT NULL,
    qtde_vendida    numeric(12, 3) NULL,
    valor_unitario  numeric(12, 4) DEFAULT 0 NOT NULL,
    filial_id       int8           DEFAULT 1 NOT NULL,
    item            int4           DEFAULT 0 NOT NULL,
    unidade_medida  varchar(3)     NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

-- Índices de apoio às consultas (ligação entrada x pedido e filtros por data)
CREATE INDEX idx_pedido_compra_ordem ON public.pedido_compra (ordem_compra);
CREATE INDEX idx_entradas_ordem ON public.entradas_mercadoria (ordem_compra);
CREATE INDEX idx_venda_data ON public.venda (data_emissao);
