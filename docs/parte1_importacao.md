# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Banco oficial do trabalho:** PostgreSQL 17 (banco `integracao`). Foi escolhido porque o enunciado pede para rodar o DDL no PostgreSQL e o script do estagiário já usa `psycopg2` e `ON CONFLICT`, que são do PostgreSQL.
- **MySQL 8/9:** usado só para validar o `sql/01_ddl_mysql.sql` (DDL executado duas vezes sem erro, mesmos dados carregados, totais conferidos e chave estrangeira testada).
- **Importação:** `scripts/importar.py` corrigido (Python 3 + pandas + openpyxl + psycopg2).

### Como reproduzir

```bash
createdb integracao
psql -d integracao -f sql/01_ddl_postgres.sql
pip install pandas openpyxl psycopg2-binary
export PGUSER=postgres PGPASSWORD='sua_senha'   # nunca no código
python scripts/importar.py
```

O script termina com uma conferência `COUNT(*)` do banco contra a planilha, e retorna código 1 se houver divergência.

## Estrutura da planilha

| Aba | Coluna | Tipo (como vem no Excel) | Observação |
| --- | --- | --- | --- |
| venda (33 linhas) | venda_id | inteiro | |
| | data_emissao | data | Vem como data, **não** como número serial |
| | horariomov | texto `08:00:00` | Gravado como `time` |
| | produto_id | texto `P1` | P21 a P28 não existem em `produtos_filial` |
| | qtde_vendida | decimal | 5 vendas fracionadas com unidade `UN` |
| | valor_unitario | decimal | |
| | filial_id | inteiro | Filiais 2 e 3 só aparecem aqui |
| | item | inteiro | |
| | unidade_medida | texto | |
| pedido_compra (29 linhas) | pedido_id, item | inteiro | |
| | data_pedido, data_entrega | data | |
| | produto_id, descricao_produto | texto | |
| | ordem_compra | inteiro | 11 pedidos com `0` (sem ordem) |
| | qtde_pedida, qtde_entregue | inteiro | |
| | preco_compra | decimal | |
| | fornecedor_id | **inteiro** `1` | Na aba `fornecedor` o código é **texto** `F1` |
| | *(colunas M a W, sem cabeçalho)* | misto | **11 colunas extras** sem nome nas linhas 22 a 30: cópia dos pedidos de P12 a P20 com outros valores. Fora do layout, ignoradas |
| entradas_mercadoria (20 linhas) | data_entrada | data | |
| | nro_nfe | texto `NFE1` | |
| | item, ordem_compra, filial_id | inteiro | `ordem_compra` liga a entrada ao pedido |
| | produto_id, descricao_produto | texto | |
| | qtde_recebida | inteiro | |
| | custo_unitario | decimal | |
| produtos_filial (20 linhas) | filial_id | inteiro | Só filial 1 |
| | **idproduto** | texto | Nas outras abas o nome é `produto_id` |
| | descricao | texto | |
| | estoque | inteiro | |
| | preco_unitario, preco_compra, preco_venda | decimal | |
| | idfornecedor | texto `F8` | |
| fornecedor (20 linhas) | idfornecedor | texto `F1` | |
| | razao_social | texto | |

## Erros encontrados no DDL e como foram corrigidos

Ao rodar `sql/01_ddl_enunciado.sql` no PostgreSQL 17, saiu:

```
CREATE TABLE        -- venda
CREATE TABLE        -- pedido_compra
psql:sql/01_ddl_enunciado.sql:27: ERROR:  column "ordem_compra" named in key does not exist
psql:sql/01_ddl_enunciado.sql:33: ERROR:  syntax error at or near "("
LINE 6:  CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, idp...
psql:sql/01_ddl_enunciado.sql:36: ERROR:  column "idproduto" named in key does not exist
```

Só 2 das 5 tabelas foram criadas. O PostgreSQL mostra **só o primeiro erro de cada comando**. Os outros erros só aparecem depois de corrigir o primeiro, ou ao tentar importar. Lista completa:

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | PK usa `ordem_compra`, mas a coluna não existe. É justamente o campo que liga a entrada ao pedido | Coluna `ordem_compra int8 NOT NULL` criada |
| entradas_mercadoria | `item` como `float8` | `int4` |
| produtos_filial | Falta vírgula depois de `idfonecedor int4 NULL`, então o `CONSTRAINT` vira parte da coluna (erro de sintaxe) | Vírgula incluída |
| produtos_filial | PK usa `idproduto`, que não existe (a coluna é `produto_id`) | PK `(filial_id, produto_id)` |
| produtos_filial | Erro de digitação: `decricao` | `descricao` (o script já inseria em `descricao`) |
| produtos_filial | Erro de digitação: `idfonecedor` | `idfornecedor` |
| produtos_filial | `idfonecedor int4`, mas o código do fornecedor é texto (`F8`) | `varchar(25)`, mesmo tipo de `fornecedor.idfornecedor` |
| produtos_filial | `filial_id` declarado `NULL`, mas faz parte da PK | `NOT NULL` |
| produtos_filial | `produto_id varchar(255)`, mas `varchar(25)` nas outras tabelas | `varchar(25)` em todas |
| produtos_filial | `DEFAULT '0'` (texto) em colunas numéricas | `DEFAULT 0` |
| fornecedor | Erro de digitação: `idforncedor` | `idfornecedor` (o script já inseria nesse nome) |
| fornecedor | PK `(idforncedor, idproduto)`: coluna inexistente, e fornecedor não depende de produto | PK `(idfornecedor)` |
| pedido_compra | `pedido_id`, `item` e `ordem_compra` como `float8`: chave em ponto flutuante | `int8` / `int4` / `int8` |
| pedido_compra | `pedido_id DEFAULT 0` numa coluna de PK (todo pedido sem ID viraria 0) | Default removido |
| pedido_compra | `fornecedor_id int4`, mas `fornecedor.idfornecedor` é texto | `varchar(25)` + FK para `fornecedor` |
| venda | PK chamada `pk_consumo` (nome copiado de outra tabela) | `pk_venda` |
| venda | `horariomov varchar(8)` guarda hora como texto | `time` |
| todas | Quantidades e valores em `float8` (erro de arredondamento em somas de R$) | `numeric(12,3)` para quantidades e `numeric(12,4)` para valores |
| todas | Nenhuma chave estrangeira; ordem de criação ignora dependências | FKs `produtos_filial → fornecedor` e `pedido_compra → fornecedor`; tabelas criadas na ordem certa; `DROP TABLE IF EXISTS` para poder rodar de novo |

**Por que não há FK de `venda → produtos_filial` nem de `entradas → pedido_compra`:** os dados do cliente têm vendas de produtos sem cadastro (P21 a P28) e entradas com ordem de compra inexistente (19 e 20). Uma FK recusaria essas linhas e esconderia o problema. Elas foram importadas como vieram e são apontadas nas consultas de validação (Parte 4), para o cliente decidir o que fazer. Além disso, `pedido_compra.ordem_compra` não é única (11 pedidos com `0`), então não pode ser alvo de FK.

**MySQL (`sql/01_ddl_mysql.sql`):** mesmo modelo, com `BIGINT/INT/DECIMAL` no lugar de `int8/int4/numeric`, sem `public.` e sem casts `::character varying`, com `ENGINE=InnoDB` (exigido para FK) e `utf8mb4`.

## Erros encontrados no script de importação e como foram corrigidos

O script original foi rodado contra o DDL corrigido. Ele imprimiu "20 registros inseridos" e "Importação concluída com sucesso!", mas o `COUNT(*)` mostrou outra coisa:

| Tabela | Script original disse | `COUNT(*)` real | Planilha |
| --- | --- | --- | --- |
| fornecedor | 20 | 20 | 20 |
| produtos_filial | 20 | 20 | 20 |
| pedido_compra | (erro em todas as linhas) | **0** | 29 |
| entradas_mercadoria | 20 | 20, **com todas as datas NULL** | 20 |
| venda | 33 | **0** | 33 |

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` supõe número serial do Excel, mas o pandas já entrega `Timestamp`. `int(Timestamp)` gera `TypeError`, engolido pelo `except:` | **Todas as datas viram NULL sem aviso.** `venda` rejeita as 33 linhas (`data_emissao NOT NULL`); pedidos e entradas entram sem data | `para_data()` aceita Timestamp, date, número serial e texto; valor inválido gera erro visível |
| `except:` sem tipo | Esconde qualquer erro de conversão | Exceções tratadas por linha, com a mensagem e o número da linha da planilha |
| `conn.rollback()` dentro do loop, com `commit()` só no fim | Uma linha com erro **desfaz todas as linhas anteriores da mesma tabela** | `SAVEPOINT` por linha: só a linha com erro é descartada |
| Mensagem final usa `len(df)` (linhas da planilha) | Diz "20 registros inseridos" mesmo com 0 no banco | Conta pelo `rowcount` real e confere com `COUNT(*)` no fim |
| "Importação concluída com sucesso!" sempre | Esconde a falha | Mostra divergências e sai com código 1 |
| `fornecedor_id` lido como `int` (1, 2, ...) | Não bate com os códigos `F1`, `F2`... da tabela `fornecedor` (FK recusa as 29 linhas) | Normaliza para `F` + número (ver "Tratamentos") |
| `df.iloc[:, :12]` + renomear colunas pela posição | Funciona por acaso; se a ordem das colunas mudar, grava dado na coluna errada. As 11 colunas extras somem sem aviso | Colunas lidas **pelo nome**, com aviso das colunas ignoradas |
| Não inseria `ordem_compra` em lugar nenhum do DDL original | (o DDL nem tinha a coluna) | Coluna criada no DDL e preenchida pelo script |
| Senha `"1234"` fixa no código | Credencial no repositório | Conexão por variáveis de ambiente `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` |
| Comentário "porta do MySQL 3006" | Errado (é 3306), e o script só funciona no PostgreSQL | Removido; o script documenta que é para PostgreSQL |
| Caminho `dados/base_teste.xlsx` relativo à pasta atual | Quebra se rodar de outra pasta | Caminho relativo ao próprio script (ou variável `ARQUIVO_XLSX`) |
| `qtde_pendente` podia ficar negativa | Quando se entrega mais que o pedido | `max(pedida - entregue, 0)` |

## Tratamentos aplicados aos dados

- **Datas:** convertidas de `Timestamp` do Excel para `date`.
- **Hora (`horariomov`):** texto `08:00:00` para `time`; vazio vira `00:00:00`.
- **`produtos_filial.idproduto`** importado em `produto_id`, para o nome ser igual nas 4 tabelas.
- **`pedido_compra.fornecedor_id`:** `1` vira `F1`, `2` vira `F2`... Os 20 códigos numéricos existem na tabela `fornecedor` nesse formato. *Decisão a confirmar com o cliente na Parte 4*, porque o fornecedor do pedido não bate com o fornecedor do cadastro do produto (22 casos).
- **Colunas M a W de `pedido_compra`** (sem cabeçalho) **ignoradas**. Elas repetem os pedidos 21 a 29 com valores diferentes (por exemplo, `qtde_pedida` 91 e não 12, e uma coluna que parece ser a pendência). Ficam registradas como erro de dados para a Parte 4.
- **`qtde_pendente`** calculada como `qtde_pedida - qtde_entregue` (a planilha não tem essa coluna).
- **Nenhum outro valor foi alterado:** os demais problemas de dados foram importados como vieram e são tratados na validação.

### Problemas nos dados percebidos durante a importação (detalhar na Parte 4)

| Problema | Ocorrências |
| --- | --- |
| Vendas de produto/filial sem cadastro em `produtos_filial` | 13 vendas (P21 a P28; filiais 2 e 3) |
| Venda fracionada com unidade `UN` | 5 (vendas 4, 8, 12, 16, 26) |
| Vendas fora de jan/fev (março/2025) | 7 |
| Pedido com `data_entrega` anterior à `data_pedido` | 20 |
| Pedido com `ordem_compra = 0` | 11 (pedidos 19 a 29) |
| Mesmo produto pedido duas vezes (P12 a P20) | 9 pares |
| Entrada sem pedido correspondente (ordem 19 e 20) | 2 |
| Entrada com data anterior ao pedido | 9 |
| Quantidade recebida maior que a pedida | 7 |
| `qtde_entregue` do pedido diferente da `qtde_recebida` da entrada | 18 |
| Fornecedor do pedido diferente do fornecedor do cadastro do produto | 22 |
| Preço de compra maior que o preço de venda | 4 (P1, P8, P15, P18) |
| Fornecedores sem nenhum produto | F14, F15, F16 |

## Conferência final

Resultado do `scripts/importar.py` corrigido, conferido com `SELECT COUNT(*)` em cada tabela. Uma segunda execução não duplica nada (`ON CONFLICT DO NOTHING`):

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

```sql
SELECT 'fornecedor' AS tabela, COUNT(*) FROM fornecedor
UNION ALL SELECT 'produtos_filial', COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra', COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda', COUNT(*) FROM venda;

-- nenhuma data pode ter ficado nula
SELECT COUNT(*) FROM venda WHERE data_emissao IS NULL;               -- 0
SELECT COUNT(*) FROM pedido_compra WHERE data_pedido IS NULL;        -- 0
SELECT COUNT(*) FROM entradas_mercadoria WHERE data_entrada IS NULL; -- 0
```
