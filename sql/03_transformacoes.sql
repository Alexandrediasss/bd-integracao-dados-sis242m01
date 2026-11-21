-- 03_transformacoes
-- Nome: Maria Luiza Oliveira Teodoro (2538557)
--
-- Parte 3: transformações de dados (PostgreSQL), aplicadas a pedidos de
-- compra, vendas e produtos.
-- Pré-requisito: sql/01_ddl_postgres.sql + scripts/importar.py já executados.
--
-- Rodar:  psql -d integracao -f sql/03_transformacoes.sql


-- ============================================================
-- 3.1 Concatenar produto_id e descrição ("onde houver")
-- ============================================================
-- Formato pedido: "12345 - Detergente".
--   * CONCAT_WS(' - ', a, b) junta os valores com o separador e IGNORA os
--     NULL. Se não houver descrição, sai só o código ("P21"), sem um
--     " - " sobrando no fim. Com o operador || o resultado inteiro viraria
--     NULL quando a descrição fosse NULL.
--   * NULLIF(TRIM(x), '') trata descrição vazia ou só com espaços como
--     "não há descrição".
--   * Pedidos e entradas têm a coluna descricao_produto; vendas não têm
--     descrição, então ela vem do cadastro (produtos_filial.descricao) por
--     LEFT JOIN. P21 a P28 não têm cadastro e mostram só o código.

-- Pedidos de compra
SELECT p.pedido_id,
       CONCAT_WS(' - ', p.produto_id, NULLIF(TRIM(p.descricao_produto), '')) AS produto,
       p.qtde_pedida
  FROM pedido_compra p
 ORDER BY p.pedido_id;

-- Vendas (descrição do cadastro, quando existir)
SELECT v.venda_id,
       CONCAT_WS(' - ', v.produto_id, NULLIF(TRIM(pf.descricao), '')) AS produto,
       v.qtde_vendida
  FROM venda v
  LEFT JOIN produtos_filial pf ON pf.filial_id  = v.filial_id
                              AND pf.produto_id = v.produto_id
 ORDER BY v.venda_id;

-- Produtos (cadastro)
SELECT pf.filial_id,
       CONCAT_WS(' - ', pf.produto_id, NULLIF(TRIM(pf.descricao), '')) AS produto,
       pf.idfornecedor
  FROM produtos_filial pf
 ORDER BY pf.filial_id, pf.produto_id;


-- ============================================================
-- 3.2 Datas no formato DD/MM/YYYY
-- ============================================================
--   * TO_CHAR(data, 'DD/MM/YYYY') devolve TEXTO. Por isso a formatação só
--     é feita na exibição. Filtros e ORDER BY usam a coluna date original:
--     ordenar o texto '01/02/2025' x '31/01/2025' daria a ordem errada.
--   * Data NULL continua NULL (TO_CHAR(NULL) = NULL).

-- Pedidos de compra
SELECT p.pedido_id,
       p.produto_id,
       TO_CHAR(p.data_pedido,  'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(p.data_entrega, 'DD/MM/YYYY') AS data_entrega
  FROM pedido_compra p
 ORDER BY p.data_pedido, p.pedido_id;

-- Vendas
SELECT v.venda_id,
       v.produto_id,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao
  FROM venda v
 ORDER BY v.data_emissao, v.venda_id;

-- Entradas de mercadoria
SELECT e.nro_nfe,
       e.produto_id,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada
  FROM entradas_mercadoria e
 ORDER BY e.data_entrada, e.nro_nfe;


-- ============================================================
-- 3.3 Produtos requisitados mais de 10 vezes no período
--     (resultado no formato do exemplo do enunciado)
-- ============================================================
-- COMO INTERPRETAMOS "MAIS DE 10 VEZES":
--   "Requisitado mais de 10 vezes" = a SOMA da quantidade pedida
--   (pedido_compra.qtde_pedida) do produto no período é maior que 10.
--   Ou seja, mais de 10 unidades requisitadas, e não mais de 10 pedidos.
--
--   Por quê:
--   1. O exemplo do enunciado mostra a coluna "Qtde Requisitada" = 15, uma
--      QUANTIDADE maior que 10. É essa coluna que o filtro compara.
--   2. A outra leitura, "aparecer em mais de 10 pedidos" (COUNT(*) > 10),
--      não serve nesta base: cada produto aparece no máximo 2 vezes em
--      pedido_compra (P12 a P20). O relatório sairia sempre vazio. A
--      consulta de conferência no fim desta seção mostra isso.
--   3. Na prática, uma unidade requisitada = uma "vez" que o produto foi
--      pedido. Somar a quantidade é o que mede a demanda do produto.
--
--   Resultado nesta base: todos os 20 produtos passam do filtro, porque
--   todo produto tem pelo menos um pedido com 12 unidades ou mais. Os
--   pedidos pequenos (2 a 9 unidades, pedidos 21 a 29) são de produtos que
--   já tinham outro pedido grande. O filtro continua necessário: um produto
--   novo com 10 unidades ou menos no período ficaria de fora.
--
-- PERÍODO:
--   O enunciado não fixa o período. Usamos a data do pedido (data_pedido)
--   e todo o intervalo da base (01/01/2025 a 31/03/2025). As datas ficam
--   na CTE "periodo" para poder trocar fácil, por exemplo só fevereiro
--   (2025-02-01 a 2025-02-28), o mês da validação da Parte 4.
--
-- DEMAIS DECISÕES:
--   * O filtro (> 10) é aplicado ao TOTAL do produto no período (CTE
--     totais). Mas cada linha mostra a quantidade de cada data de
--     solicitação, como no exemplo (Produto | Qtde | Data). Se o produto
--     foi pedido em datas diferentes, aparece uma linha por data.
--   * Pedidos do mesmo produto na mesma data são somados numa linha só
--     (ex.: P12 tem os pedidos 12 e 21, ambos em 25/02/2025: 91 + 12 = 103).
--   * Descrição: a do pedido (descricao_produto). Se não houver, usa a do
--     cadastro (produtos_filial). Se não houver nenhuma, só o código.
--   * Qtde sem casas decimais (::int), como no exemplo. As quantidades de
--     pedido são todas inteiras.

WITH periodo AS (
    SELECT DATE '2025-01-01' AS inicio,
           DATE '2025-03-31' AS fim
),
pedidos_periodo AS (
    SELECT p.*
      FROM pedido_compra p, periodo
     WHERE p.data_pedido BETWEEN periodo.inicio AND periodo.fim
),
totais AS (
    SELECT produto_id, SUM(qtde_pedida) AS qtde_total
      FROM pedidos_periodo
     GROUP BY produto_id
    HAVING SUM(qtde_pedida) > 10          -- "mais de 10 vezes"
),
descricoes AS (
    SELECT produto_id, MIN(descricao) AS descricao
      FROM produtos_filial
     GROUP BY produto_id
)
SELECT CONCAT_WS(' - ', pp.produto_id,
                 COALESCE(NULLIF(TRIM(MAX(pp.descricao_produto)), ''), d.descricao))
                                              AS "Produto",
       SUM(pp.qtde_pedida)::int               AS "Qtde Requisitada",
       TO_CHAR(pp.data_pedido, 'DD/MM/YYYY')  AS "Data Solicitação"
  FROM pedidos_periodo pp
  JOIN totais t          ON t.produto_id = pp.produto_id
  LEFT JOIN descricoes d ON d.produto_id = pp.produto_id
 GROUP BY pp.produto_id, d.descricao, pp.data_pedido
 ORDER BY pp.data_pedido, pp.produto_id;

-- Conferência das duas interpretações, por produto, no mesmo período:
--   qtde_pedidos  = quantas vezes o produto aparece em pedido_compra
--   qtde_unidades = soma de qtde_pedida (interpretação escolhida)
-- Nenhum produto tem qtde_pedidos > 10, e todos têm qtde_unidades > 10.
SELECT p.produto_id,
       COUNT(*)                         AS qtde_pedidos,
       SUM(p.qtde_pedida)::int          AS qtde_unidades,
       COUNT(*) > 10                    AS passa_por_contagem,
       SUM(p.qtde_pedida) > 10          AS passa_por_quantidade
  FROM pedido_compra p
 WHERE p.data_pedido BETWEEN DATE '2025-01-01' AND DATE '2025-03-31'
 GROUP BY p.produto_id
 ORDER BY COUNT(*) DESC, p.produto_id;


-- ============================================================
-- 3.4 Trigger: gera automaticamente um novo idfornecedor
-- ============================================================
-- O que faz: ao inserir um produto em produtos_filial SEM idfornecedor
-- (NULL ou vazio), a trigger:
--   1. gera o próximo código de fornecedor (F21, F22, ...);
--   2. cria esse fornecedor na tabela fornecedor;
--   3. grava o código no produto.
-- Assim o produto sempre fica relacionado a um fornecedor que existe (a
-- chave estrangeira produtos_filial_fornecedor_fk continua valendo).
-- Se o produto já vier com fornecedor, a trigger não mexe em nada.
--
-- Decisões:
--   * "idfornecedor numérico" (enunciado): na base o código é texto com
--     prefixo (F1 a F20), e é por esse texto que fornecedor se liga a
--     produtos_filial e pedido_compra. Para não quebrar a relação, o que é
--     numérico e sequencial é a parte depois do "F". Trocar para int
--     exigiria mudar o DDL e converter os dados das três tabelas.
--   * SEQUENCE em vez de MAX()+1: com MAX()+1, dois cadastros simultâneos
--     leriam o mesmo MAX e gerariam o mesmo código. nextval() nunca entrega
--     o mesmo número duas vezes, nem em transações paralelas.
--   * O LOOP pula códigos que já existam (ex.: alguém cadastrou F21 à mão),
--     em vez de dar erro de chave duplicada.
--   * BEFORE INSERT: a trigger precisa alterar a linha (NEW) antes de ela
--     ser gravada. O fornecedor é criado antes do produto, então a FK já
--     encontra o fornecedor quando é verificada.
--   * razao_social é NOT NULL: o fornecedor nasce com uma razão social
--     provisória ("A DEFINIR ..."), que o cliente deve completar depois.
--   * Sequência e ROLLBACK: nextval() não volta atrás em ROLLBACK, então
--     um teste desfeito "gasta" um número (pode haver buraco, ex.: F21 e
--     depois F23). É o comportamento normal e esperado de sequences. O que
--     importa é o código ser único.

-- Sequência dos números de fornecedor, começando após o maior código atual
-- (F20 -> o próximo será F21). O setval deixa o script seguro para rodar
-- de novo, mesmo depois de recriar as tabelas com o 01_ddl_postgres.sql.
CREATE SEQUENCE IF NOT EXISTS public.fornecedor_codigo_seq;

SELECT setval('public.fornecedor_codigo_seq',
              COALESCE((SELECT MAX(SUBSTRING(idfornecedor FROM 2)::int)
                          FROM public.fornecedor
                         WHERE idfornecedor ~ '^F[0-9]+$'), 0) + 1,
              false);  -- false: o próximo nextval() devolve exatamente esse valor

CREATE OR REPLACE FUNCTION public.fn_gera_idfornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo varchar(25);
BEGIN
    -- produto já veio com fornecedor: respeita o que foi informado
    IF NULLIF(TRIM(NEW.idfornecedor), '') IS NOT NULL THEN
        RETURN NEW;
    END IF;

    -- próximo código livre: F + número da sequência
    LOOP
        v_codigo := 'F' || nextval('public.fornecedor_codigo_seq');
        EXIT WHEN NOT EXISTS (SELECT 1
                                FROM public.fornecedor
                               WHERE idfornecedor = v_codigo);
    END LOOP;

    -- cria o fornecedor relacionado
    INSERT INTO public.fornecedor (idfornecedor, razao_social)
    VALUES (v_codigo, 'A DEFINIR - gerado automaticamente para o produto ' || NEW.produto_id);

    -- relaciona o produto ao fornecedor criado
    NEW.idfornecedor := v_codigo;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_idfornecedor ON public.produtos_filial;

CREATE TRIGGER trg_gera_idfornecedor
    BEFORE INSERT ON public.produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_gera_idfornecedor();


-- ------------------------------------------------------------
-- Teste da trigger
-- ------------------------------------------------------------
-- Roda dentro de uma transação desfeita no fim (ROLLBACK), para não
-- deixar produtos e fornecedores de teste na base que vai ser validada
-- com o cliente (as contagens da Parte 1 continuam 20 / 20).
--   P30: sem fornecedor (NULL)  -> deve ganhar F21 (criado em fornecedor)
--   P31: fornecedor vazio ('')  -> deve ganhar F22
--   P32: já com fornecedor F3   -> deve continuar F3 (nada é criado)

BEGIN;

INSERT INTO public.produtos_filial (filial_id, produto_id, descricao, idfornecedor)
VALUES (1, 'P30', 'Detergente',  NULL),
       (1, 'P31', 'Sabão em pó', ''),
       (1, 'P32', 'Esponja',     'F3');

SELECT CONCAT_WS(' - ', pf.produto_id, pf.descricao) AS produto,
       pf.idfornecedor,
       f.razao_social
  FROM public.produtos_filial pf
  JOIN public.fornecedor f ON f.idfornecedor = pf.idfornecedor
 WHERE pf.produto_id IN ('P30', 'P31', 'P32')
 ORDER BY pf.produto_id;

SELECT COUNT(*) AS fornecedores_durante_o_teste FROM public.fornecedor;  -- 22

ROLLBACK;

SELECT COUNT(*) AS fornecedores_depois_do_rollback FROM public.fornecedor;  -- 20
