# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

**Objetivo da reunião:** confirmar com o cliente que os dados de **fevereiro de 2025** carregados no banco estão completos e corretos, e decidir junto com ele o que fazer com cada inconsistência encontrada na planilha enviada.

**Como a reunião funciona:** para cada ponto, mostramos um número tirado do banco e o cliente compara com os controles dele (fechamento de caixa, relatório de compras, notas fiscais). Nenhum dado foi alterado ou "corrigido por conta própria": tudo foi importado como veio, e cada problema tem uma consulta que mostra exatamente quais linhas estão afetadas. Assim o cliente decide, com base nos documentos dele, qual informação é a correta.

Todas as consultas citadas (códigos P01, V01 a V07, E01 a E16 e C01) estão em `sql/04_validacao.sql`. O critério de "fevereiro" é a data de emissão da venda, a data do pedido e a data de entrada da mercadoria, entre 01/02/2025 e 28/02/2025.

## 1. Pontos a validar

### 1.1 Totais de vendas do mês

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| **14 vendas, 173,22 unidades, R$ 14.093,17** em fevereiro (V03). Filial 1: 13 vendas, R$ 13.545,64. Filial 2: 1 venda, R$ 547,53. Filial 3: nenhuma venda em fevereiro. | "Esses totais batem com o fechamento de caixa / relatório de vendas de fevereiro do seu sistema, por filial?" |
| As vendas de fevereiro estão concentradas em **6 dias**: 07, 17, 18, 20, 22 e 28/02 (V04). | "É normal ter vendas em só 6 dias de fevereiro, ou faltam movimentos de outros dias na planilha?" |
| A planilha tem vendas de janeiro (12), fevereiro (14) e março (7) (V02). | "A base deveria conter só fevereiro ou os três meses? Os meses de janeiro e março estão completos?" |

### 1.2 Vendas de produtos sem cadastro

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| **6 vendas de fevereiro** (P22 a P27) são de produtos que **não existem no cadastro**: R$ 3.241,24, ou seja, **23% do faturamento do mês** (E01). A filial 2 também não tem nenhum produto cadastrado. | "Os produtos P21 a P28 existem? Por que não estão no cadastro? Qual o cadastro das filiais 2 e 3?" |
| Cada uma dessas vendas tem **exatamente o mesmo preço e a mesma data** de uma venda de outro produto (P22 = P14, P23 = P15, ..., P27 = P19) (E03). | "Essas vendas podem ter sido lançadas com o código de produto errado? Se sim, qual é o código correto?" |

Se forem códigos errados, o **total do mês não muda**, mas muda o total **por produto** (consulta 2.1 da Parte 2).

### 1.3 Qual preço de venda vale

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| **Nenhuma** venda tem o preço igual ao `preco_venda` do cadastro (8 vendas de fevereiro com cadastro, todas diferentes) (E04). O cadastro ainda tem um segundo preço, `preco_unitario`, que também não bate com nenhum dos dois. | "Qual é o preço de venda oficial do produto: `preco_venda`, `preco_unitario` ou o preço praticado em cada venda (promoções, descontos)?" |
| 4 produtos têm **preço de compra maior que o de venda** (P1, P8, P15, P18), ou seja, margem negativa (E05). | "Esses produtos realmente são vendidos com prejuízo ou o preço do cadastro está desatualizado?" |
| 2 vendas de fevereiro com quantidade fracionada (37,11 e 3,11) em unidade **UN** (E02). | "Esses produtos são vendidos a granel (kg, litro)? Se sim, qual a unidade correta? Se não, qual a quantidade certa?" |

### 1.4 Compras e entradas do mês

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| **Pedidos** com data em fevereiro: 17 linhas, 619 unidades, R$ 28.396,93. **Entradas** de mercadoria em fevereiro: 10 notas, 468 unidades, R$ 36.722,92 (V06). | "Batem com o relatório de compras e com o registro de notas fiscais de entrada de fevereiro?" |
| 9 pedidos de fevereiro estão **sem ordem de compra** (ordem = 0), e 7 deles repetem outro pedido do mesmo produto na mesma data (E07, E08). | "Os pedidos 21 a 29 são pedidos complementares de verdade ou cópias que deveriam ser apagadas?" |
| A nota **NFE19** (entrada em 13/02, 64 unidades de P19) aponta para a ordem de compra 19, que **não existe** (E09). A NFE20 (janeiro) aponta para a ordem 20, que também não existe. Na planilha, as colunas extras da aba `pedido_compra` trazem uma versão dos pedidos com as ordens 19 e 20 preenchidas (para P19 e P20, com quantidades diferentes das do banco: 40 e 86 unidades, contra 20 e 25). | "As notas NFE19 e NFE20 são dos pedidos 19 e 20 (P19 e P20)? A versão correta dos pedidos é a que está nas colunas extras da planilha?" |

### 1.5 Datas, quantidades e custos: pedido x nota fiscal

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| 16 pedidos de fevereiro têm **data de entrega anterior à data do pedido** (E06). 2 notas de fevereiro entraram **antes de o pedido existir** (E10). | "O campo `data_pedido` é a data de emissão do pedido ou outra data (aprovação, lançamento no sistema)?" |
| 2 notas de fevereiro trouxeram **mais do que foi pedido** (E11). Em 9, a quantidade da nota é diferente da que o pedido registra como entregue (E12). | "Para o estoque, vale a quantidade da nota fiscal ou a do pedido? É permitido receber mais do que foi pedido?" |
| Em 9 notas de fevereiro o custo unitário é diferente do preço de compra do pedido (E14), e em 8 a data de entrada é diferente da entrega registrada no pedido (E13). | "Para custo e data de recebimento, qual documento é o oficial: a nota fiscal ou o pedido?" |

### 1.6 Fornecedores

| O que mostramos | Pergunta ao cliente |
| --- | --- |
| Na planilha, o fornecedor do pedido vinha como número (1, 2, ...) e o do cadastro como código (F1, F2, ...). Convertemos 1 → F1. Mesmo assim, em 11 pedidos de fevereiro o fornecedor do pedido é diferente do fornecedor do cadastro do produto (E15). | "O número do fornecedor no pedido corresponde ao código F do cadastro? Um produto pode ser comprado de mais de um fornecedor?" |
| F14, F15 e F16 estão cadastrados, mas não fornecem nenhum produto (E16). | "Esses fornecedores estão ativos? O cadastro de produtos está completo?" |

## 2. Técnicas para garantir exatidão e precisão

| Técnica | Como aplicamos | Resultado |
| --- | --- | --- |
| **Contagem planilha x banco** | O script de importação conta as linhas de cada aba e compara com `COUNT(*)` no banco; se houver diferença, ele avisa e termina com erro. A mesma conferência está na V01. | 5 tabelas, todas iguais: 20, 20, 29, 20, 33 linhas. |
| **Totais de controle** | A soma das vendas por produto tem que ser igual ao total geral (V05). O total por filial tem uma linha de total geral (V03). Uma venda perdida ou duplicada por um JOIN errado aparece como diferença. | Diferença de **R$ 0,00**. |
| **Recálculo por outra ferramenta** | O total de fevereiro foi recalculado direto da planilha original, sem passar pelo banco (Python/pandas; no Excel, basta filtrar fevereiro e somar quantidade × valor). | 14 vendas, 173,22 unidades, R$ 14.093,17: **igual** ao banco. |
| **Comparação com os relatórios do cliente** | Os números de V03, V04 e V06 são comparados com o fechamento de caixa, o relatório de compras e o registro de notas fiscais de entrada do sistema do cliente. | A confirmar na reunião. |
| **Conferência por amostragem** | Escolher algumas linhas e comparar com o documento original (cupom/nota): a maior venda do mês (venda 14, P14, R$ 5.633,90), uma venda sem cadastro (venda 22, P22), a nota NFE19 e um pedido sem ordem (pedido 21). | A confirmar na reunião. |
| **Cruzamento entre tabelas** | Pedido x entrada pela `ordem_compra` + produto (V07, E09 a E14); venda x cadastro de produtos (E01, E04); pedido e cadastro x fornecedor (E15, E16). | Inconsistências listadas na seção "Erros encontrados nos dados". |
| **Checagens de valores impossíveis** | Datas vazias ou fora de 2025, quantidades e valores zerados ou negativos, produto sem descrição, estoque negativo, produto apontando para fornecedor inexistente (C01). | **Todas zeradas.** |
| **Tipos de dados corretos** | Valores e quantidades em `numeric` (decimal exato) em vez de `float`: somas de dinheiro não têm erro de arredondamento. Datas em `date`, hora em `time`. Chaves estrangeiras garantem que todo produto e pedido aponte para um fornecedor que existe. | Ver `sql/01_ddl_postgres.sql`. |
| **Importação que não esconde erros** | A importação registra cada linha recusada com o motivo, em vez de "engolir" o erro (o script original gravava todas as datas como vazias sem avisar). | 0 linhas recusadas. |
| **Dados preservados** | Nenhum valor foi alterado para "consertar" a base. Os problemas foram importados como vieram e são mostrados pelas consultas E01 a E16. Quem decide a correção é o cliente. | Rastreabilidade: cada número do relatório pode ser conferido na planilha original. |
| **Reprodutibilidade** | DDL, script e consultas estão versionados no repositório. Rodar de novo gera exatamente os mesmos resultados. | Depois das correções do cliente, basta reimportar e rodar P01 e C01 de novo. |

## 3. Consultas preparadas para a reunião

Ordem sugerida para a reunião: começar pelo painel (P01), mostrar que a carga está completa (V01, V02), conferir os números do mês (V03 a V07), passar pelos erros (E01 a E16) e fechar com o que está correto (C01).

### P01: Painel de qualidade

Uma tabela-resumo com uma linha por tipo de problema (E01 a E16): quantos casos existem na base toda e quantos caem em fevereiro. É o "índice" da reunião: o cliente vê de uma vez o tamanho de cada problema, e cada linha leva à consulta detalhada com o mesmo código. Os números estão na tabela "Erros encontrados nos dados", no fim deste documento.

### Conferências de fevereiro (V01 a V07)

| Código | O que mostra, em linguagem simples | Números principais |
| --- | --- | --- |
| **V01** | Quantas linhas de cada tabela entraram no banco, ao lado de quantas havia na planilha. Prova de que nada se perdeu na carga. | 20 / 20 / 29 / 20 / 33, todas iguais à planilha. |
| **V02** | Quantas vendas, pedidos e entradas existem em cada mês. Mostra o período que o cliente enviou. | Vendas: jan 12, fev 14, mar 7. Pedidos: jan 11, fev 17, mar 1. Entradas: jan 9, fev 10, mar 1. |
| **V03** | Total vendido em fevereiro por filial, com o total geral na última linha. É o número para comparar com o fechamento de caixa. | Filial 1: R$ 13.545,64. Filial 2: R$ 547,53. **Total: 14 vendas, 173,22 unidades, R$ 14.093,17.** |
| **V04** | Vendas de fevereiro dia a dia. Facilita achar em qual dia está uma diferença, se o total não bater. | 6 dias com venda. Maior dia: 07/02, R$ 6.271,70. |
| **V05** | Prova de que a soma das vendas por produto é igual ao total geral, ou seja, nenhuma venda foi perdida nem contada duas vezes. | Diferença R$ 0,00. |
| **V06** | Total de pedidos de compra feitos em fevereiro e de mercadorias que entraram em fevereiro. Para comparar com o setor de compras e com as notas fiscais. | Pedidos: 17, 619 unidades, R$ 28.396,93. Entradas: 10 notas, 468 unidades, R$ 36.722,92. |
| **V07** | Cada pedido de fevereiro lado a lado com a nota fiscal ligada a ele: datas, quantidades e preços. É a consulta mais útil para discutir os problemas de compras, porque mostra todos juntos. | 17 pedidos. 9 sem nota ligada (pedidos sem ordem de compra). |

Também ficam prontas as consultas da Parte 2 (`sql/02_consultas.sql`), que respondem às perguntas de negócio: vendas de fevereiro por produto (2.1) e produtos requisitados e não recebidos (2.2: 11 pedidos, 9 de fevereiro).

### Erros nos dados (E01 a E16)

Cada consulta E lista **as linhas exatas** que têm o problema, para o cliente conferir no documento original. O resumo de todas, com as quantidades, está na tabela "Erros encontrados nos dados". Alguns problemas se sobrepõem: por exemplo, as vendas de E01 (sem cadastro) são as mesmas de E03 (preço copiado de outro produto); por isso as quantidades **não devem ser somadas** entre si.

### C01: O que foi verificado e está correto

Lista de checagens que **precisam dar zero** e deram zero: nenhuma data vazia ou fora de 2025, nenhuma quantidade ou valor zerado ou negativo, nenhum produto sem descrição ou com estoque negativo, nenhum produto ligado a um fornecedor que não existe. Fecha a reunião mostrando ao cliente que, além dos pontos a decidir, a base não tem erros "grosseiros".

### Depois da reunião

1. Registrar em ata a decisão do cliente para cada linha da tabela de erros.
2. Corrigir na origem (planilha ou sistema do cliente) e reimportar com `scripts/importar.py`.
3. Rodar de novo P01, V03 e C01: os erros resolvidos devem zerar e os totais devem bater com o relatório do cliente.

## Erros encontrados nos dados

Quantidade = total na base (quantos são de fevereiro). Cadastros não têm data, então não há recorte de fevereiro.

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| venda | Venda de produto/filial sem cadastro em `produtos_filial` (P21 a P28; filiais 2 e 3 sem nenhum produto cadastrado) | 13 (6 em fev., R$ 3.241,24) | E01 |
| venda | Quantidade fracionada em unidade `UN` (vendas 4, 8, 12, 16 e 26) | 5 (2 em fev.) | E02 |
| venda | Venda que repete preço (e quase sempre data) de venda de outro produto: P21 a P28 copiam P13 a P20; indício de código de produto errado | 13 (6 em fev.) | E03 |
| venda x produtos_filial | Preço da venda diferente do `preco_venda` do cadastro (nenhuma venda bate); `preco_unitario` do cadastro também diverge | 20 (8 em fev.) | E04 |
| produtos_filial | Preço de compra maior que o preço de venda: margem negativa (P1, P8, P15, P18) | 4 | E05 |
| pedido_compra | Data de entrega anterior à data do pedido | 20 (16 em fev.) | E06 |
| pedido_compra | Pedido sem ordem de compra (`ordem_compra = 0`): nenhuma entrada pode ser ligada a ele (pedidos 19 a 29) | 11 (9 em fev.) | E07 |
| pedido_compra | Pedido duplicado: mesmo produto e mesma data em outro pedido (pedidos 21 a 29 repetem P12 a P20, com outra quantidade e sem ordem) | 18 linhas = 9 pares (14 em fev.) | E08 |
| entradas_mercadoria | Entrada com ordem de compra inexistente (NFE19 → ordem 19, NFE20 → ordem 20) | 2 (1 em fev.) | E09 |
| entradas_mercadoria x pedido_compra | Mercadoria entrou antes da data do pedido | 9 (2 em fev.) | E10 |
| entradas_mercadoria x pedido_compra | Quantidade recebida maior que a pedida | 7 (2 em fev.) | E11 |
| entradas_mercadoria x pedido_compra | Quantidade entregue registrada no pedido diferente da recebida na nota (todas as 18 entradas ligadas a um pedido) | 18 (9 em fev.) | E12 |
| entradas_mercadoria x pedido_compra | Data de entrega do pedido diferente da data real de entrada | 17 (8 em fev.) | E13 |
| entradas_mercadoria x pedido_compra | Custo unitário da nota diferente do preço de compra do pedido (todas as 18 entradas ligadas a um pedido) | 18 (9 em fev.) | E14 |
| pedido_compra x produtos_filial | Fornecedor do pedido diferente do fornecedor do cadastro do produto | 22 (11 em fev.) | E15 |
| fornecedor | Fornecedor cadastrado sem nenhum produto (F14, F15, F16) | 3 | E16 |
| planilha (aba `pedido_compra`) | 11 colunas extras sem cabeçalho (colunas M a W, linhas 22 a 30): uma segunda versão dos pedidos de P12 a P20, com ordem de compra preenchida (12 a 20, incluindo as ordens 19 e 20 citadas pelas notas NFE19 e NFE20), quantidades iguais às dos pedidos 12 a 18 (para P19 e P20, 40 e 86 unidades, contra 20 e 25 no banco) e uma coluna de pendência. Ficam fora do layout e foram ignoradas na importação (ver `docs/parte1_importacao.md`) | 11 colunas × 9 linhas | Sem consulta (não está no banco) |
