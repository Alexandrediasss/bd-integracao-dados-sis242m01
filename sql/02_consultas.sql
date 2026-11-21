-- 02_consultas
-- Nome: Maria Luiza Oliveira Teodoro (2538557)
--
-- Parte 2: consultas SQL básicas (PostgreSQL).
-- Pré-requisito: sql/01_ddl_postgres.sql + scripts/importar.py já executados.
--
-- Rodar:  psql -d integracao -f sql/02_consultas.sql


-- ============================================================
-- 2.1 Consumo por produto em fevereiro de 2025
--     Total vendido em quantidade e em R$ por produto.
-- ============================================================
-- Decisões:
--   * R$ = qtde_vendida * valor_unitario, somado por produto.
--     A soma é feita em numeric (sem erro de arredondamento do float),
--     e só o resultado final é arredondado para 2 casas.
--   * Filtro de data por intervalo [2025-02-01, 2025-03-01) em vez de
--     EXTRACT(MONTH ...) ou TO_CHAR(...): assim o PostgreSQL pode usar o
--     índice idx_venda_data, e não tem problema com o último dia do mês.
--   * A descrição vem de produtos_filial com LEFT JOIN: as vendas de
--     P21 a P28 não têm cadastro e um INNER JOIN as faria SUMIR do total.
--     Elas aparecem com "(sem cadastro)".
--   * As vendas são somadas ANTES do JOIN (CTE vendas_fev), e a descrição
--     vem de uma lista com um produto por linha (CTE descricoes). Se o
--     mesmo produto estivesse cadastrado em mais de uma filial, um JOIN
--     direto multiplicaria as vendas.

WITH vendas_fev AS (
    SELECT v.produto_id,
           COUNT(*)                                 AS qtde_vendas,
           SUM(v.qtde_vendida)                      AS qtde_total,
           SUM(v.qtde_vendida * v.valor_unitario)   AS valor_total
      FROM venda v
     WHERE v.data_emissao >= DATE '2025-02-01'
       AND v.data_emissao <  DATE '2025-03-01'
     GROUP BY v.produto_id
),
descricoes AS (
    SELECT produto_id, MIN(descricao) AS descricao
      FROM produtos_filial
     GROUP BY produto_id
)
SELECT vf.produto_id,
       COALESCE(d.descricao, '(sem cadastro)')  AS descricao,
       vf.qtde_vendas,
       vf.qtde_total                            AS qtde_vendida,
       ROUND(vf.valor_total, 2)                 AS total_vendido_rs
  FROM vendas_fev vf
  LEFT JOIN descricoes d ON d.produto_id = vf.produto_id
 ORDER BY total_vendido_rs DESC, vf.produto_id;

-- Conferência: total geral de fevereiro (deve bater com a soma da consulta acima)
SELECT COUNT(*)                                            AS qtde_vendas,
       SUM(qtde_vendida)                                   AS qtde_vendida,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)        AS total_vendido_rs
  FROM venda
 WHERE data_emissao >= DATE '2025-02-01'
   AND data_emissao <  DATE '2025-03-01';


-- ============================================================
-- 2.2 Produtos requisitados e não recebidos
--     Itens de pedido_compra sem nenhuma entrada_mercadoria.
-- ============================================================
-- Decisões:
--   * A ligação pedido x entrada é o campo ordem_compra (enunciado). Também
--     comparamos produto_id, porque uma mesma ordem pode ter vários produtos
--     e a entrada de um não significa que o outro chegou.
--   * NOT EXISTS em vez de LEFT JOIN ... IS NULL ou NOT IN: lê melhor
--     ("não existe entrada para este pedido"), nunca duplica linhas e não
--     tem a armadilha do NOT IN com NULL.
--   * Pedidos com ordem_compra = 0 significam "sem ordem de compra": nenhuma
--     entrada pode ser ligada a eles, então todos aparecem aqui (11 pedidos).
--   * Atenção (para a Parte 4): as entradas NFE19 (P19) e NFE20 (P20)
--     apontam para as ordens 19 e 20, que não existem em pedido_compra.
--     Os pedidos 19 e 20 (P19 e P20) estão com ordem 0. Parece que a
--     mercadoria chegou, mas a ordem do pedido não foi preenchida. Pelo
--     vínculo oficial (ordem_compra) eles continuam "não recebidos", e a
--     coluna observacao avisa o caso para validar com o cliente.

WITH entradas_sem_pedido AS (
    -- entradas cuja ordem_compra não existe em nenhum pedido (NFE19 e NFE20)
    SELECT e.produto_id, e.nro_nfe, e.ordem_compra
      FROM entradas_mercadoria e
     WHERE NOT EXISTS (SELECT 1
                         FROM pedido_compra p
                        WHERE p.ordem_compra = e.ordem_compra)
)
SELECT p.pedido_id,
       p.item,
       p.ordem_compra,
       p.produto_id,
       p.descricao_produto,
       p.data_pedido,
       p.qtde_pedida,
       p.fornecedor_id,
       CASE
           WHEN p.ordem_compra = 0 THEN 'pedido sem ordem de compra'
           ELSE 'ordem sem entrada de mercadoria'
       END AS motivo,
       (SELECT 'entrada ' || esp.nro_nfe || ' (ordem ' || esp.ordem_compra
               || ', inexistente) é deste produto: validar com o cliente'
          FROM entradas_sem_pedido esp
         WHERE esp.produto_id = p.produto_id
         LIMIT 1) AS observacao
  FROM pedido_compra p
 WHERE NOT EXISTS (SELECT 1
                     FROM entradas_mercadoria e
                    WHERE e.ordem_compra = p.ordem_compra
                      AND e.produto_id   = p.produto_id)
 ORDER BY p.produto_id, p.pedido_id;


-- ============================================================
-- 2.3 Complemento: pedidos recebidos só em parte
-- ============================================================
-- "Não recebido" também pode ser lido como "não recebido por completo".
-- Esta consulta mostra os pedidos COM entrada, mas cuja quantidade recebida
-- (soma das entradas da mesma ordem e produto) é menor que a pedida.
-- As entradas são somadas antes do JOIN para não duplicar o pedido se
-- houver mais de uma nota fiscal para a mesma ordem.

WITH recebido AS (
    SELECT ordem_compra, produto_id, SUM(qtde_recebida) AS qtde_recebida
      FROM entradas_mercadoria
     GROUP BY ordem_compra, produto_id
)
SELECT p.pedido_id,
       p.ordem_compra,
       p.produto_id,
       p.descricao_produto,
       p.qtde_pedida,
       r.qtde_recebida,
       p.qtde_pedida - r.qtde_recebida AS saldo_a_receber
  FROM pedido_compra p
  JOIN recebido r ON r.ordem_compra = p.ordem_compra
                 AND r.produto_id   = p.produto_id
 WHERE r.qtde_recebida < p.qtde_pedida
 ORDER BY saldo_a_receber DESC, p.produto_id;
