-- 04_validacao
-- Nome: Carlos Alexandre Dias Messias de Lima (2423449)
--
-- Parte 4: consultas prontas para a reunião de validação dos dados de
-- FEVEREIRO/2025 com o cliente (PostgreSQL).
-- Pré-requisito: sql/01_ddl_postgres.sql + scripts/importar.py já executados.
--
-- Rodar tudo:  psql -d integracao -f sql/04_validacao.sql
-- (ou abrir no DBeaver e executar consulta por consulta)
--
-- Organização (os códigos são citados em docs/parte4_validacao.md):
--   P01        Painel: todas as checagens de erro, com total e quantos são de fevereiro
--   V01 a V07  Conferências: números de fevereiro para o cliente comparar
--              com o sistema/controles dele
--   E01 a E16  Erros nos dados: cada consulta lista as linhas com o problema
--   C01        Checagens de integridade que devem voltar ZERADAS
--
-- Fevereiro/2025 = data >= '2025-02-01' AND data < '2025-03-01'.
-- Referência de data de cada tabela: venda.data_emissao,
-- pedido_compra.data_pedido, entradas_mercadoria.data_entrada.
--
-- Nenhuma consulta deste arquivo altera dados (só SELECT).


-- ============================================================
-- P01  PAINEL DE QUALIDADE (abrir a reunião com ele)
-- ============================================================
-- Uma linha por checagem de erro (E01 a E16), com o total na base e quanto
-- disso cai em fevereiro/2025. Cadastros (produtos, fornecedores) não têm
-- data: a coluna de fevereiro fica vazia.

WITH fev AS (SELECT DATE '2025-02-01' AS ini, DATE '2025-03-01' AS fim)
SELECT codigo, checagem, total, em_fevereiro
  FROM (
    SELECT 'E01' AS codigo, 'Venda de produto/filial sem cadastro' AS checagem,
           COUNT(*) AS total,
           COUNT(*) FILTER (WHERE v.data_emissao >= fev.ini AND v.data_emissao < fev.fim) AS em_fevereiro
      FROM venda v CROSS JOIN fev
      LEFT JOIN produtos_filial pf ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
     WHERE pf.produto_id IS NULL
    UNION ALL
    SELECT 'E02', 'Venda fracionada com unidade UN', COUNT(*),
           COUNT(*) FILTER (WHERE v.data_emissao >= fev.ini AND v.data_emissao < fev.fim)
      FROM venda v CROSS JOIN fev
     WHERE v.unidade_medida = 'UN' AND v.qtde_vendida <> TRUNC(v.qtde_vendida)
    UNION ALL
    SELECT 'E03', 'Venda que repete o preço de outro produto já vendido', COUNT(*),
           COUNT(*) FILTER (WHERE v.data_emissao >= fev.ini AND v.data_emissao < fev.fim)
      FROM venda v CROSS JOIN fev
     WHERE EXISTS (SELECT 1 FROM venda o
                    WHERE o.valor_unitario = v.valor_unitario
                      AND o.produto_id <> v.produto_id
                      AND o.venda_id < v.venda_id)
    UNION ALL
    SELECT 'E04', 'Venda com preço diferente do preço de venda do cadastro', COUNT(*),
           COUNT(*) FILTER (WHERE v.data_emissao >= fev.ini AND v.data_emissao < fev.fim)
      FROM venda v CROSS JOIN fev
      JOIN produtos_filial pf ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
     WHERE v.valor_unitario <> pf.preco_venda
    UNION ALL
    SELECT 'E05', 'Produto com preço de compra maior que o de venda', COUNT(*), NULL
      FROM produtos_filial WHERE preco_compra > preco_venda
    UNION ALL
    SELECT 'E06', 'Pedido com entrega anterior ao pedido', COUNT(*),
           COUNT(*) FILTER (WHERE p.data_pedido >= fev.ini AND p.data_pedido < fev.fim)
      FROM pedido_compra p CROSS JOIN fev
     WHERE p.data_entrega < p.data_pedido
    UNION ALL
    SELECT 'E07', 'Pedido sem ordem de compra (ordem_compra = 0)', COUNT(*),
           COUNT(*) FILTER (WHERE p.data_pedido >= fev.ini AND p.data_pedido < fev.fim)
      FROM pedido_compra p CROSS JOIN fev
     WHERE p.ordem_compra = 0
    UNION ALL
    SELECT 'E08', 'Pedido duplicado (mesmo produto e data em outro pedido)', COUNT(*),
           COUNT(*) FILTER (WHERE p.data_pedido >= fev.ini AND p.data_pedido < fev.fim)
      FROM pedido_compra p CROSS JOIN fev
     WHERE EXISTS (SELECT 1 FROM pedido_compra o
                    WHERE o.produto_id = p.produto_id
                      AND o.data_pedido = p.data_pedido
                      AND o.pedido_id <> p.pedido_id)
    UNION ALL
    SELECT 'E09', 'Entrada com ordem de compra inexistente', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
     WHERE NOT EXISTS (SELECT 1 FROM pedido_compra p WHERE p.ordem_compra = e.ordem_compra)
    UNION ALL
    SELECT 'E10', 'Entrada anterior à data do pedido', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
      JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
     WHERE e.data_entrada < p.data_pedido
    UNION ALL
    SELECT 'E11', 'Quantidade recebida maior que a pedida', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
      JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
     WHERE e.qtde_recebida > p.qtde_pedida
    UNION ALL
    SELECT 'E12', 'Qtde entregue no pedido diferente da recebida na entrada', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
      JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
     WHERE e.qtde_recebida <> p.qtde_entregue
    UNION ALL
    SELECT 'E13', 'Data de entrega do pedido diferente da data da entrada', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
      JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
     WHERE e.data_entrada <> p.data_entrega
    UNION ALL
    SELECT 'E14', 'Custo da entrada diferente do preço de compra do pedido', COUNT(*),
           COUNT(*) FILTER (WHERE e.data_entrada >= fev.ini AND e.data_entrada < fev.fim)
      FROM entradas_mercadoria e CROSS JOIN fev
      JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
     WHERE e.custo_unitario <> p.preco_compra
    UNION ALL
    SELECT 'E15', 'Fornecedor do pedido diferente do fornecedor do cadastro', COUNT(*),
           COUNT(*) FILTER (WHERE p.data_pedido >= fev.ini AND p.data_pedido < fev.fim)
      FROM pedido_compra p CROSS JOIN fev
      JOIN produtos_filial pf ON pf.filial_id = p.filial_id AND pf.produto_id = p.produto_id
     WHERE pf.idfornecedor <> p.fornecedor_id
    UNION ALL
    SELECT 'E16', 'Fornecedor cadastrado sem nenhum produto', COUNT(*), NULL
      FROM fornecedor f
     WHERE NOT EXISTS (SELECT 1 FROM produtos_filial pf WHERE pf.idfornecedor = f.idfornecedor)
  ) painel
 ORDER BY codigo;


-- ============================================================
-- V01  Conferência da carga: linhas por tabela
-- ============================================================
-- Esperado (linhas da planilha base_teste.xlsx): fornecedor 20,
-- produtos_filial 20, pedido_compra 29, entradas_mercadoria 20, venda 33.

SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas_no_banco, 20 AS linhas_na_planilha FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*), 20 FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*), 29 FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*), 20 FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*), 33 FROM venda;


-- ============================================================
-- V02  Movimento por mês (onde fevereiro se encaixa)
-- ============================================================
-- Mostra que a base tem janeiro, fevereiro e março, e quanto de cada
-- tabela é de fevereiro. Serve para o cliente confirmar o período enviado.

SELECT 'venda' AS tabela, TO_CHAR(data_emissao, 'MM/YYYY') AS mes, COUNT(*) AS linhas
  FROM venda GROUP BY 1, 2
UNION ALL
SELECT 'pedido_compra', TO_CHAR(data_pedido, 'MM/YYYY'), COUNT(*)
  FROM pedido_compra GROUP BY 1, 2
UNION ALL
SELECT 'entradas_mercadoria', TO_CHAR(data_entrada, 'MM/YYYY'), COUNT(*)
  FROM entradas_mercadoria GROUP BY 1, 2
 ORDER BY 1, 2;


-- ============================================================
-- V03  Vendas de fevereiro: totais por filial
-- ============================================================
-- Total geral de fevereiro: 14 vendas, 173,220 unidades, R$ 14.093,17.
-- O cliente compara com o fechamento de caixa / relatório do sistema dele.

SELECT v.filial_id,
       COUNT(*)                                          AS qtde_vendas,
       SUM(v.qtde_vendida)                               AS qtde_vendida,
       ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)  AS total_rs
  FROM venda v
 WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
 GROUP BY ROLLUP (v.filial_id)          -- última linha (filial vazia) = total geral
 ORDER BY v.filial_id NULLS LAST;


-- ============================================================
-- V04  Vendas de fevereiro: dia a dia
-- ============================================================
-- Conferência por data, mais fácil de bater com o movimento diário da loja.

SELECT TO_CHAR(v.data_emissao, 'DD/MM/YYYY')            AS data,
       COUNT(*)                                          AS qtde_vendas,
       SUM(v.qtde_vendida)                               AS qtde_vendida,
       ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)  AS total_rs
  FROM venda v
 WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
 GROUP BY v.data_emissao
 ORDER BY v.data_emissao;


-- ============================================================
-- V05  Vendas de fevereiro: prova de que por produto = total
-- ============================================================
-- A soma da consulta 2.1 (vendas por produto) tem que dar exatamente o
-- total geral. Diferença diferente de zero indicaria venda perdida ou
-- duplicada por JOIN.

WITH base AS (
    SELECT * FROM venda
     WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
),
por_produto AS (
    SELECT produto_id, SUM(qtde_vendida * valor_unitario) AS total
      FROM base GROUP BY produto_id
)
SELECT ROUND((SELECT SUM(total) FROM por_produto), 2)                        AS soma_por_produto,
       ROUND((SELECT SUM(qtde_vendida * valor_unitario) FROM base), 2)        AS total_geral,
       ROUND((SELECT SUM(total) FROM por_produto)
             - (SELECT SUM(qtde_vendida * valor_unitario) FROM base), 2)      AS diferenca;


-- ============================================================
-- V06  Compras de fevereiro: pedidos e entradas
-- ============================================================
-- Pedidos feitos em fevereiro e mercadorias que entraram em fevereiro,
-- com quantidades e valores, para o cliente bater com o setor de compras.

SELECT 'pedidos (data_pedido em fev)'                    AS conferencia,
       COUNT(*)                                          AS linhas,
       SUM(qtde_pedida)                                  AS qtde,
       ROUND(SUM(qtde_pedida * preco_compra), 2)         AS valor_rs
  FROM pedido_compra
 WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
UNION ALL
SELECT 'entradas (data_entrada em fev)',
       COUNT(*),
       SUM(qtde_recebida),
       ROUND(SUM(qtde_recebida * custo_unitario), 2)
  FROM entradas_mercadoria
 WHERE data_entrada >= DATE '2025-02-01' AND data_entrada < DATE '2025-03-01';


-- ============================================================
-- V07  Pedido x entrada, lado a lado (fevereiro)
-- ============================================================
-- Cada pedido de fevereiro com a entrada ligada a ele pela ordem_compra.
-- É a consulta mais útil para o cliente ver de uma vez os problemas de
-- E06, E07, E10 a E14.

SELECT p.pedido_id,
       p.ordem_compra,
       CONCAT_WS(' - ', p.produto_id, p.descricao_produto) AS produto,
       TO_CHAR(p.data_pedido,  'DD/MM/YYYY')  AS data_pedido,
       TO_CHAR(p.data_entrega, 'DD/MM/YYYY')  AS entrega_prevista,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY')  AS data_entrada,
       p.qtde_pedida,
       p.qtde_entregue                        AS entregue_no_pedido,
       e.qtde_recebida                        AS recebida_na_nfe,
       p.preco_compra,
       e.custo_unitario,
       e.nro_nfe
  FROM pedido_compra p
  LEFT JOIN entradas_mercadoria e ON e.ordem_compra = p.ordem_compra
                                 AND e.produto_id   = p.produto_id
 WHERE p.data_pedido >= DATE '2025-02-01' AND p.data_pedido < DATE '2025-03-01'
 ORDER BY p.data_pedido, p.pedido_id;


-- ============================================================
-- ERROS NOS DADOS
-- Cada consulta abaixo lista as linhas com o problema.
-- (Erro que não aparece no banco: a aba pedido_compra da planilha tem 11
--  colunas extras sem cabeçalho, colunas M a W, linhas 22 a 30, com uma
--  cópia dos pedidos de P12 a P20 com outros valores. Foram ignoradas na
--  importação; ver docs/parte1_importacao.md.)
-- ============================================================

-- E01  Venda de produto/filial sem cadastro em produtos_filial
--      (P21 a P28; filiais 2 e 3 não têm nenhum produto cadastrado)
SELECT v.venda_id, TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao,
       v.filial_id, v.produto_id, v.qtde_vendida, v.valor_unitario
  FROM venda v
  LEFT JOIN produtos_filial pf ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
 WHERE pf.produto_id IS NULL
 ORDER BY v.data_emissao, v.venda_id;

-- E02  Venda com quantidade fracionada em unidade "UN" (unidade inteira)
SELECT venda_id, TO_CHAR(data_emissao, 'DD/MM/YYYY') AS data_emissao,
       produto_id, qtde_vendida, unidade_medida
  FROM venda
 WHERE unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
 ORDER BY venda_id;

-- E03  Venda que repete o preço unitário de OUTRO produto vendido antes.
--      As vendas de P21 a P28 copiam o preço (e quase sempre a data) de
--      P13 a P20: indício de código de produto digitado errado.
SELECT v.venda_id,
       v.produto_id,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY')  AS data_emissao,
       v.valor_unitario,
       o.venda_id                              AS venda_original,
       o.produto_id                            AS produto_original,
       TO_CHAR(o.data_emissao, 'DD/MM/YYYY')  AS data_original,
       (v.data_emissao = o.data_emissao)       AS mesma_data
  FROM venda v
  JOIN venda o ON o.valor_unitario = v.valor_unitario
              AND o.produto_id <> v.produto_id
              AND o.venda_id < v.venda_id
 ORDER BY v.venda_id, o.venda_id;

-- E04  Venda com preço diferente do preço de venda do cadastro
--      (e, no cadastro, preco_unitario também nunca bate com preco_venda:
--       não está claro qual dos dois é o preço de venda)
SELECT v.venda_id, v.produto_id,
       v.valor_unitario                 AS preco_na_venda,
       pf.preco_venda                   AS preco_venda_cadastro,
       pf.preco_unitario                AS preco_unitario_cadastro,
       v.valor_unitario - pf.preco_venda AS diferenca
  FROM venda v
  JOIN produtos_filial pf ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
 WHERE v.valor_unitario <> pf.preco_venda
 ORDER BY ABS(v.valor_unitario - pf.preco_venda) DESC;

-- E05  Produto com preço de compra maior que o preço de venda (margem negativa)
SELECT produto_id, descricao, preco_compra, preco_venda,
       ROUND(preco_venda - preco_compra, 2) AS margem
  FROM produtos_filial
 WHERE preco_compra > preco_venda
 ORDER BY margem;

-- E06  Pedido com data de entrega anterior à data do pedido
SELECT pedido_id, produto_id,
       TO_CHAR(data_pedido,  'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega,
       data_pedido - data_entrega           AS dias_antes
  FROM pedido_compra
 WHERE data_entrega < data_pedido
 ORDER BY pedido_id;

-- E07  Pedido sem ordem de compra (ordem_compra = 0): não dá para ligar
--      nenhuma entrada de mercadoria a ele
SELECT pedido_id, produto_id, TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
       qtde_pedida, qtde_entregue
  FROM pedido_compra
 WHERE ordem_compra = 0
 ORDER BY pedido_id;

-- E08  Pedido duplicado: mesmo produto na mesma data em pedidos diferentes
--      (pedidos 21 a 29 repetem 12 a 20 com outras quantidades e sem ordem)
SELECT p.produto_id,
       TO_CHAR(p.data_pedido, 'DD/MM/YYYY')                 AS data_pedido,
       STRING_AGG(p.pedido_id::text, ', ' ORDER BY p.pedido_id) AS pedidos,
       STRING_AGG(p.ordem_compra::text, ', ' ORDER BY p.pedido_id) AS ordens,
       STRING_AGG(p.qtde_pedida::int::text, ', ' ORDER BY p.pedido_id) AS qtdes_pedidas
  FROM pedido_compra p
 GROUP BY p.produto_id, p.data_pedido
HAVING COUNT(*) > 1
 ORDER BY p.data_pedido, p.produto_id;

-- E09  Entrada de mercadoria com ordem de compra que não existe em pedido_compra
SELECT e.nro_nfe, e.ordem_compra, e.produto_id,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada, e.qtde_recebida
  FROM entradas_mercadoria e
 WHERE NOT EXISTS (SELECT 1 FROM pedido_compra p WHERE p.ordem_compra = e.ordem_compra)
 ORDER BY e.ordem_compra;

-- E10  Mercadoria que entrou ANTES de ser pedida
SELECT e.nro_nfe, p.pedido_id, e.produto_id,
       TO_CHAR(p.data_pedido,  'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada,
       p.data_pedido - e.data_entrada          AS dias_antes
  FROM entradas_mercadoria e
  JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
 WHERE e.data_entrada < p.data_pedido
 ORDER BY dias_antes DESC;

-- E11  Quantidade recebida maior que a quantidade pedida
SELECT e.nro_nfe, p.pedido_id, e.produto_id,
       p.qtde_pedida, e.qtde_recebida,
       e.qtde_recebida - p.qtde_pedida AS excesso
  FROM entradas_mercadoria e
  JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
 WHERE e.qtde_recebida > p.qtde_pedida
 ORDER BY excesso DESC;

-- E12  Quantidade entregue registrada no pedido diferente da recebida na nota
SELECT e.nro_nfe, p.pedido_id, e.produto_id,
       p.qtde_entregue AS entregue_no_pedido,
       e.qtde_recebida AS recebida_na_nfe,
       e.qtde_recebida - p.qtde_entregue AS diferenca
  FROM entradas_mercadoria e
  JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
 WHERE e.qtde_recebida <> p.qtde_entregue
 ORDER BY ABS(e.qtde_recebida - p.qtde_entregue) DESC;

-- E13  Data de entrega do pedido diferente da data real da entrada
SELECT e.nro_nfe, p.pedido_id, e.produto_id,
       TO_CHAR(p.data_entrega, 'DD/MM/YYYY') AS entrega_no_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada,
       e.data_entrada - p.data_entrega         AS dias_diferenca
  FROM entradas_mercadoria e
  JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
 WHERE e.data_entrada <> p.data_entrega
 ORDER BY ABS(e.data_entrada - p.data_entrega) DESC;

-- E14  Custo unitário da entrada diferente do preço de compra do pedido
SELECT e.nro_nfe, p.pedido_id, e.produto_id,
       p.preco_compra     AS preco_no_pedido,
       e.custo_unitario   AS custo_na_nfe,
       ROUND(e.custo_unitario - p.preco_compra, 2) AS diferenca
  FROM entradas_mercadoria e
  JOIN pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
 WHERE e.custo_unitario <> p.preco_compra
 ORDER BY ABS(e.custo_unitario - p.preco_compra) DESC;

-- E15  Fornecedor do pedido diferente do fornecedor do cadastro do produto
--      (na planilha o fornecedor do pedido vinha como número, ex.: 1 -> F1;
--       ver docs/parte1_importacao.md. Confirmar com o cliente qual vale.)
SELECT p.pedido_id, p.produto_id,
       p.fornecedor_id   AS fornecedor_no_pedido,
       pf.idfornecedor   AS fornecedor_no_cadastro
  FROM pedido_compra p
  JOIN produtos_filial pf ON pf.filial_id = p.filial_id AND pf.produto_id = p.produto_id
 WHERE pf.idfornecedor <> p.fornecedor_id
 ORDER BY p.pedido_id;

-- E16  Fornecedor cadastrado que não fornece nenhum produto
--      (informativo: pode ser normal, mas vale confirmar se o cadastro está completo)
SELECT f.idfornecedor, f.razao_social
  FROM fornecedor f
 WHERE NOT EXISTS (SELECT 1 FROM produtos_filial pf WHERE pf.idfornecedor = f.idfornecedor)
 ORDER BY f.idfornecedor;


-- ============================================================
-- C01  Checagens de integridade que devem voltar TODAS ZERADAS
-- ============================================================
-- Mostram ao cliente o que foi verificado e está correto: nenhuma data
-- vazia, nenhuma quantidade ou valor zerado/negativo, nenhuma data fora
-- de 2025, nenhum produto sem descrição.

SELECT 'venda sem data / qtde ou valor <= 0' AS checagem,
       COUNT(*) FILTER (WHERE data_emissao IS NULL OR qtde_vendida IS NULL
                          OR qtde_vendida <= 0 OR valor_unitario <= 0) AS ocorrencias
  FROM venda
UNION ALL
SELECT 'pedido sem data / qtde pedida <= 0 / preço <= 0',
       COUNT(*) FILTER (WHERE data_pedido IS NULL OR qtde_pedida IS NULL
                          OR qtde_pedida <= 0 OR preco_compra <= 0)
  FROM pedido_compra
UNION ALL
SELECT 'entrada sem data / qtde recebida <= 0 / custo <= 0',
       COUNT(*) FILTER (WHERE data_entrada IS NULL OR qtde_recebida IS NULL
                          OR qtde_recebida <= 0 OR custo_unitario <= 0)
  FROM entradas_mercadoria
UNION ALL
SELECT 'datas fora de 2025',
       (SELECT COUNT(*) FROM venda WHERE EXTRACT(YEAR FROM data_emissao) <> 2025)
     + (SELECT COUNT(*) FROM pedido_compra
         WHERE EXTRACT(YEAR FROM data_pedido) <> 2025 OR EXTRACT(YEAR FROM data_entrega) <> 2025)
     + (SELECT COUNT(*) FROM entradas_mercadoria WHERE EXTRACT(YEAR FROM data_entrada) <> 2025)
UNION ALL
SELECT 'produto sem descrição / estoque negativo',
       COUNT(*) FILTER (WHERE TRIM(descricao) = '' OR estoque < 0)
  FROM produtos_filial
UNION ALL
SELECT 'produto do cadastro com fornecedor inexistente',
       COUNT(*) FILTER (WHERE idfornecedor IS NOT NULL
                          AND NOT EXISTS (SELECT 1 FROM fornecedor f
                                           WHERE f.idfornecedor = pf.idfornecedor))
  FROM produtos_filial pf;
