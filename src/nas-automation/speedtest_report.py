#!/usr/bin/env python3

import mysql.connector
from datetime import datetime, timedelta
from pathlib import Path
import sys
import hashlib
from dotenv import load_dotenv
import os

load_dotenv()


def validar_env():
    load_dotenv(os.path.expanduser("/home/Emerson/.secrets.env"))
    obrigatorias = ["DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME"]
    faltando = [v for v in obrigatorias if not os.getenv(v)]

    if faltando:
        print(f"Variáveis de ambiente ausentes: {', '.join(faltando)}")
        sys.exit(1)


validar_env()


DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "port": int(os.getenv("DB_PORT")),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
}

hoje = datetime.today().replace(day=1)
ultimo_dia_mes_anterior = hoje - timedelta(days=1)
primeiro_dia_mes_anterior = ultimo_dia_mes_anterior.replace(day=1)

MES_ANO = ultimo_dia_mes_anterior.strftime("%m/%Y")
DATA_INICIO = primeiro_dia_mes_anterior.strftime("%d/%m/%Y")
DATA_FIM = ultimo_dia_mes_anterior.strftime("%d/%m/%Y")
ARQUIVO_MES = ultimo_dia_mes_anterior.strftime("%Y_%m")

EMPRESA = "Núcleo MAP - Máquinas, Automação e Programação"
CNPJ = "30.945.466/0001-20"
RESPONSAVEL_TECNICO = "Emerson Martins Brito"
CARGO = "Especialista em automação"
CONTATO = "emerson@nucleomap.com.br"

TEMPLATE_PATH = "template_relatorio.md"
OUTPUT_DIR = "/volume1/Reports"

VELOCIDADE_CONTRATADA_MBPS = 1000  # Defina a velocidade contratada aqui
MINIMO_ACEITAVEL_MBPS_DOWNLOAD = VELOCIDADE_CONTRATADA_MBPS * 0.4  # 40% da contratada
MINIMO_ACEITAVEL_MBPS_UPLOAD = VELOCIDADE_CONTRATADA_MBPS * 0.2  # 20% da contratada
MEDIA_ACEITAVEL_MBPS_DOWNLOAD = VELOCIDADE_CONTRATADA_MBPS * 0.8  # 80% da contratada
MEDIA_ACEITAVEL_MBPS_UPLOAD = VELOCIDADE_CONTRATADA_MBPS * 0.4  # 40% da contratada
MAXIMO_PING_ACEITAVEL_MS = 40  # ms
ANALISE_TECNICA_MENSAL = ""


def read_from_database():
    try:
        conn = mysql.connector.connect(**DB_CONFIG, connection_timeout=10)
        cursor = conn.cursor(dictionary=True)

        query = """
            SELECT
            	MIN(download)					AS minimo_download,
                MIN(upload)						AS minimo_upload,
                MAX(latency)						AS maximo_latencia,
                ROUND(AVG(download), 2)         AS media_download,
                ROUND(AVG(upload), 2)           AS media_upload,
                ROUND(AVG(latency), 2)             AS media_latencia,
                ROUND(AVG(jitter), 2)           AS media_jitter,
                ROUND(AVG(packetloss), 2)   AS media_pacote_perdido,
                DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01') AS inicio,
                DATE_FORMAT(CURRENT_DATE, '%Y-%m-01') AS fim,
                DATE_FORMAT(CURRENT_DATE, '%Y') AS ano,
                DATE_FORMAT(CURRENT_DATE, '%m') AS mes,
                COUNT(*) AS total_medicoes
            FROM results
            WHERE `datetime` >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
            AND `datetime` <  DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');
        """

        cursor.execute(query)
        dados = cursor.fetchone()

        cursor.close()
        conn.close()

        print("Success data read from database!")

        return dados

    except mysql.connector.Error as e:
        print(f"Error reading from database: {e}")
        sys.exit(1)


def gerar_analise_tecnica(dados):
    analise = []

    analise.append(
        "Durante o período avaliado, os indicadores de desempenho "
        "apresentaram comportamento compatível com o perfil do serviço monitorado."
    )

    if (
        dados["minimo_download"] is not None
        and dados["minimo_download"] < MINIMO_ACEITAVEL_MBPS_DOWNLOAD
    ):
        analise.append(
            f"**Alerta:** Velocidade mínima de download abaixo do esperado "
            f"({dados['minimo_download']} Mbps)."
        )

    if (
        dados["minimo_upload"] is not None
        and dados["minimo_upload"] < MINIMO_ACEITAVEL_MBPS_UPLOAD
    ):
        analise.append(
            f"**Alerta:** Velocidade mínima de upload abaixo do esperado "
            f"({dados['minimo_upload']} Mbps)."
        )

    if (
        dados["media_download"] is not None
        and dados["media_download"] < MEDIA_ACEITAVEL_MBPS_DOWNLOAD
    ):
        analise.append(
            f"**Alerta:** Média mensal de download abaixo do esperado "
            f"({dados['media_download']} Mbps)."
        )

    if (
        dados["media_upload"] is not None
        and dados["media_upload"] < MEDIA_ACEITAVEL_MBPS_UPLOAD
    ):
        analise.append(
            f"**Alerta:** Média mensal de upload abaixo do esperado "
            f"({dados['media_upload']} Mbps)."
        )

    if (
        dados["maximo_latencia"] is not None
        and dados["maximo_latencia"] > MAXIMO_PING_ACEITAVEL_MS
    ):
        analise.append(
            f"**Alerta:** Latência máxima registrada acima do aceitável "
            f"({dados['maximo_latencia']} ms)."
        )

    if len(analise) == 1:
        analise.append(
            "Não foram observadas degradações persistentes que comprometessem "
            "a qualidade da conexão durante o mês de referência."
        )

    return "\n\n".join(analise)


def gerar_hash_sha256(conteudo: str) -> str:
    sha = hashlib.sha256()
    sha.update(conteudo.encode("utf-8"))
    return sha.hexdigest()


def relatorio_markdown():
    dados = read_from_database()

    if not dados or dados["total_medicoes"] == 0:
        print("Nenhum dado para gerar o relatório.")
        return None

    analise_tecnica = gerar_analise_tecnica(dados)

    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        template = f.read()

    relatorio = template.format(
        EMPRESA=EMPRESA,
        CNPJ=CNPJ,
        RESPONSAVEL_TECNICO=RESPONSAVEL_TECNICO,
        CONTATO=CONTATO,
        CARGO=CARGO,
        MES_ANO=MES_ANO,
        DATA_INICIO=DATA_INICIO,
        DATA_FIM=DATA_FIM,
        DATA_EMISSAO=datetime.today().strftime("%d/%m/%Y"),
        TOTAL_MEDICOES=dados["total_medicoes"],
        MEDIA_DOWNLOAD=dados["media_download"],
        MEDIA_UPLOAD=dados["media_upload"],
        MEDIA_PING=dados["media_ping"],
        MEDIA_JITTER=dados["media_jitter"],
        MEDIA_PERDA=dados["media_pacote_perdido"],
        ANALISE_TECNICA_MENSAL=analise_tecnica,
    )

    hash_sha256 = gerar_hash_sha256(relatorio)

    # O hash é calculado antes da inclusão do rodapé

    rodape_hash = f"""

---

### 🔐 Integridade do Documento

Este relatório possui integridade garantida por hash criptográfico.

- **Algoritmo:** SHA256  
- **Hash:** `{hash_sha256}`  

Qualquer alteração no conteúdo invalida este hash.
"""

    relatorio += rodape_hash

    Path(OUTPUT_DIR).mkdir(exist_ok=True)

    output_file = f"{OUTPUT_DIR}/Relatorio_Desempenho_Internet_{ARQUIVO_MES}.md"

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(relatorio)

    with open(f"{output_file}.sha256", "w", encoding="utf-8") as f:
        f.write(f"{hash_sha256}  {Path(output_file).name}\n")

    print(f"Relatório gerado com sucesso: {output_file}")

    return dados


if __name__ == "__main__":
    print(f"Start report in {datetime.now()}")
    dados = relatorio_markdown()

    if dados:
        print("Médias do mês anterior")
        print(f"Média de download:   {dados['media_download']} Mbps")
        print(f"Média de upload:   {dados['media_upload']} Mbps")
        print(f"Média de latência:   {dados['media_ping']} ms")
        print(f"Média de jitter:   {dados['media_jitter']} ms")
        print(f"Média de perda de pacotes:   {dados['media_pacote_perdido']} %")
        print(f"Período analisado: {DATA_INICIO} a {DATA_FIM}")
        print(f"Total de medições: {dados['total_medicoes']}")

    else:
        print("Nenhum dado encontrado")
