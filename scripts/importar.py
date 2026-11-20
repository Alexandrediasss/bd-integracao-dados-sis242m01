"""
Importa dados/base_teste.xlsx para o PostgreSQL.

Pré-requisito: rodar antes sql/01_ddl_postgres.sql no banco de destino.

Conexão por variáveis de ambiente (nenhuma senha fica no código):
    PGHOST      (padrão: localhost)
    PGPORT      (padrão: 5432)
    PGDATABASE  (padrão: integracao)
    PGUSER      (padrão: postgres)
    PGPASSWORD  (sem padrão; se não for definida, o psycopg2 usa ~/.pgpass
                 ou a autenticação local do servidor)

Uso:
    pip install pandas openpyxl psycopg2-binary
    export PGPASSWORD='sua_senha'
    python scripts/importar.py

Correções em relação ao script original: ver docs/parte1_importacao.md.
"""

import os
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path

import pandas as pd
import psycopg2

# ── Configurações ──────────────────────────────────────────
RAIZ = Path(__file__).resolve().parent.parent
ARQUIVO = Path(os.environ.get("ARQUIVO_XLSX", RAIZ / "dados" / "base_teste.xlsx"))

DB = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "dbname": os.environ.get("PGDATABASE", "integracao"),
    "user": os.environ.get("PGUSER", "postgres"),
}
if os.environ.get("PGPASSWORD"):
    DB["password"] = os.environ["PGPASSWORD"]


# ── Conversões ─────────────────────────────────────────────
def vazio(valor):
    return valor is None or (not isinstance(valor, str) and pd.isna(valor)) or (
        isinstance(valor, str) and valor.strip() == ""
    )


def para_data(valor):
    """Aceita data do Excel já convertida (Timestamp/datetime/date),
    número serial do Excel ou texto. Valor inválido gera erro (não vira NULL
    em silêncio, como no script original)."""
    if vazio(valor):
        return None
    if isinstance(valor, pd.Timestamp):
        return valor.date()
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    if isinstance(valor, (int, float)):
        return (datetime(1899, 12, 30) + timedelta(days=int(valor))).date()
    return pd.to_datetime(str(valor).strip(), dayfirst=True).date()


def para_hora(valor, padrao="00:00:00"):
    if vazio(valor):
        return padrao
    if isinstance(valor, (time, datetime, pd.Timestamp)):
        return valor.strftime("%H:%M:%S")
    return str(valor).strip()


def para_num(valor, padrao=None):
    return padrao if vazio(valor) else float(valor)


def para_int(valor, padrao=None):
    if vazio(valor):
        return padrao
    numero = float(valor)
    if numero != int(numero):
        raise ValueError(f"valor {valor!r} deveria ser inteiro")
    return int(numero)


def para_texto(valor, padrao=None):
    if vazio(valor):
        return padrao
    if isinstance(valor, float) and valor.is_integer():
        valor = int(valor)
    return str(valor).strip()


def codigo_fornecedor(valor):
    """Na aba pedido_compra o fornecedor vem como número (1, 2, ...), mas na
    aba fornecedor o código é texto (F1, F2, ...). Normaliza para o padrão
    da tabela fornecedor, senão a chave estrangeira não fecha."""
    texto = para_texto(valor)
    if texto is None:
        return None
    return texto if texto.upper().startswith("F") else f"F{texto}"


# ── Carga genérica ─────────────────────────────────────────
def ler_aba(nome, colunas):
    """Lê só as colunas esperadas, pelo NOME (o original cortava pela
    posição com iloc e renomeava às cegas)."""
    df = pd.read_excel(ARQUIVO, sheet_name=nome)
    df.columns = [str(c).strip() for c in df.columns]
    faltando = [c for c in colunas if c not in df.columns]
    if faltando:
        raise KeyError(f"aba {nome}: colunas ausentes {faltando}")
    ignoradas = [c for c in df.columns if c not in colunas]
    if ignoradas:
        print(f"  aviso (aba {nome}): {len(ignoradas)} coluna(s) fora do layout ignorada(s): {ignoradas}")
    df = df[colunas]
    # descarta linhas totalmente vazias (sujeira comum em planilhas)
    return df.dropna(how="all")


def importar(conn, tabela, sql, df, montar_linha):
    """Insere linha a linha com SAVEPOINT: uma linha com erro é descartada
    sozinha, sem desfazer as anteriores (o rollback do original desfazia a
    transação inteira)."""
    print(f"Importando {tabela}...")
    inseridos = duplicados = 0
    erros = []
    with conn.cursor() as cur:
        for indice, row in df.iterrows():
            linha_excel = indice + 2  # +1 cabeçalho, +1 base 1
            cur.execute("SAVEPOINT linha")
            try:
                cur.execute(sql, montar_linha(row))
                if cur.rowcount == 1:
                    inseridos += 1
                else:
                    duplicados += 1
                cur.execute("RELEASE SAVEPOINT linha")
            except Exception as e:  # registra e segue para a próxima linha
                cur.execute("ROLLBACK TO SAVEPOINT linha")
                erros.append((linha_excel, str(e).strip().splitlines()[0]))
    conn.commit()
    print(f"  planilha: {len(df)} | inseridos: {inseridos} | "
          f"ignorados por chave duplicada: {duplicados} | com erro: {len(erros)}")
    for linha_excel, msg in erros:
        print(f"    linha {linha_excel} da planilha: {msg}")
    return len(df), erros


# ── Definição de cada aba ──────────────────────────────────
def main():
    print(f"Conectando em {DB['host']}:{DB['port']}/{DB['dbname']} como {DB['user']}...")
    conn = psycopg2.connect(**DB)
    print("Conectado!\n")

    resultado = {}

    # 1. FORNECEDOR (primeiro: é referenciado pelas outras tabelas)
    df = ler_aba("fornecedor", ["idfornecedor", "razao_social"])
    resultado["fornecedor"] = importar(conn, "fornecedor", """
        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (%s, %s)
        ON CONFLICT (idfornecedor) DO NOTHING
    """, df, lambda r: (
        para_texto(r["idfornecedor"]),
        para_texto(r["razao_social"]),
    ))

    # 2. PRODUTOS_FILIAL (na planilha a coluna chama idproduto)
    df = ler_aba("produtos_filial", ["filial_id", "idproduto", "descricao", "estoque",
                                     "preco_unitario", "preco_compra", "preco_venda",
                                     "idfornecedor"])
    resultado["produtos_filial"] = importar(conn, "produtos_filial", """
        INSERT INTO public.produtos_filial
            (filial_id, produto_id, descricao, estoque,
             preco_unitario, preco_compra, preco_venda, idfornecedor)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (filial_id, produto_id) DO NOTHING
    """, df, lambda r: (
        para_int(r["filial_id"]),
        para_texto(r["idproduto"]),
        para_texto(r["descricao"]),
        para_num(r["estoque"], 0),
        para_num(r["preco_unitario"], 0),
        para_num(r["preco_compra"], 0),
        para_num(r["preco_venda"], 0),
        para_texto(r["idfornecedor"]),
    ))

    # 3. PEDIDO_COMPRA (a aba tem 11 colunas extras sem cabeçalho: ignoradas)
    df = ler_aba("pedido_compra", ["pedido_id", "data_pedido", "item", "produto_id",
                                   "descricao_produto", "ordem_compra", "qtde_pedida",
                                   "filial_id", "data_entrega", "qtde_entregue",
                                   "preco_compra", "fornecedor_id"])

    def linha_pedido(r):
        pedida = para_num(r["qtde_pedida"])
        entregue = para_num(r["qtde_entregue"], 0)
        pendente = max(pedida - entregue, 0) if pedida is not None else 0
        return (
            para_int(r["pedido_id"]),
            para_data(r["data_pedido"]),
            para_int(r["item"]),
            para_texto(r["produto_id"]),
            para_texto(r["descricao_produto"]),
            para_int(r["ordem_compra"], 0),
            pedida,
            para_int(r["filial_id"]),
            para_data(r["data_entrega"]),
            entregue,
            pendente,
            para_num(r["preco_compra"], 0),
            codigo_fornecedor(r["fornecedor_id"]),
        )

    resultado["pedido_compra"] = importar(conn, "pedido_compra", """
        INSERT INTO public.pedido_compra
            (pedido_id, data_pedido, item, produto_id, descricao_produto,
             ordem_compra, qtde_pedida, filial_id, data_entrega,
             qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (pedido_id, produto_id, item) DO NOTHING
    """, df, linha_pedido)

    # 4. ENTRADAS_MERCADORIA
    df = ler_aba("entradas_mercadoria", ["data_entrada", "nro_nfe", "item", "produto_id",
                                         "descricao_produto", "ordem_compra",
                                         "qtde_recebida", "filial_id", "custo_unitario"])
    resultado["entradas_mercadoria"] = importar(conn, "entradas_mercadoria", """
        INSERT INTO public.entradas_mercadoria
            (data_entrada, nro_nfe, item, produto_id, descricao_produto,
             ordem_compra, qtde_recebida, filial_id, custo_unitario)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING
    """, df, lambda r: (
        para_data(r["data_entrada"]),
        para_texto(r["nro_nfe"]),
        para_int(r["item"]),
        para_texto(r["produto_id"]),
        para_texto(r["descricao_produto"]),
        para_int(r["ordem_compra"]),
        para_num(r["qtde_recebida"]),
        para_int(r["filial_id"]),
        para_num(r["custo_unitario"], 0),
    ))

    # 5. VENDA
    df = ler_aba("venda", ["venda_id", "data_emissao", "horariomov", "produto_id",
                           "qtde_vendida", "valor_unitario", "filial_id", "item",
                           "unidade_medida"])
    resultado["venda"] = importar(conn, "venda", """
        INSERT INTO public.venda
            (venda_id, data_emissao, horariomov, produto_id,
             qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING
    """, df, lambda r: (
        para_int(r["venda_id"]),
        para_data(r["data_emissao"]),
        para_hora(r["horariomov"]),
        para_texto(r["produto_id"]),
        para_num(r["qtde_vendida"]),
        para_num(r["valor_unitario"], 0),
        para_int(r["filial_id"], 1),
        para_int(r["item"], 0),
        para_texto(r["unidade_medida"]),
    ))

    # ── Conferência: planilha x banco (COUNT(*) real) ─────────
    print("\nConferência (linhas na planilha x linhas no banco):")
    ok = True
    with conn.cursor() as cur:
        for tabela, (na_planilha, erros) in resultado.items():
            cur.execute(f"SELECT COUNT(*) FROM public.{tabela}")
            no_banco = cur.fetchone()[0]
            situacao = "OK" if no_banco == na_planilha and not erros else "DIVERGENTE"
            ok = ok and situacao == "OK"
            print(f"  {tabela:<20} planilha={na_planilha:<4} banco={no_banco:<4} {situacao}")
    conn.close()

    print("=" * 40)
    print("Importação concluída sem divergências." if ok
          else "Importação concluída COM DIVERGÊNCIAS: veja as mensagens acima.")
    print("=" * 40)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
