#!/usr/bin/env python3

import subprocess
import json
import mysql.connector
from datetime import datetime
import sys
import time
from dotenv import load_dotenv
import os

load_dotenv()

def validar_env():
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


def test_speed():
    try:
        print(f"Start test in {datetime.now()}")

        # Executar speedtest oficial e obter JSON
        result = subprocess.run(
            ["speedtest", "--accept-license", "--accept-gdpr", "-f", "json"],
            capture_output=True,
            text=True,
            timeout=120,
        )

        if result.returncode != 0:
            print(f"Speedtest error: {result.stderr}")
            return None

        # Parse do JSON
        data = json.loads(result.stdout)

        # Extrair dados
        download = data["download"]["bandwidth"] / 125_000  # bits para Mbps
        upload = data["upload"]["bandwidth"] / 125_000
        ping = data["ping"]["latency"]
        jitter = data["ping"]["jitter"]
        pacote_perdido = data["packetLoss"] if "packetLoss" in data else 0
        servidor = f"{data['server']['name']} - {data['server']['location']} - {data['server']['country']}"
        ip_externo = data["interface"]["externalIp"]
        result_id = data["result"]["id"]
        result_url = data["result"]["url"]

        print(f"Download: {download:.2f} Mbps")
        print(f"Upload: {upload:.2f} Mbps")
        print(f"Ping: {ping:.2f} ms")
        print(f"Jitter: {jitter:.2f} ms")
        return {
            "download": download,
            "upload": upload,
            "ping": ping,
            "jitter": jitter,
            "pacote_perdido": pacote_perdido,
            "servidor": servidor,
            "ip_externo": ip_externo,
            "result_id": result_id,
            "result_url": result_url,
        }

    except Exception as e:
        print(f"Error test: {e}")
        return None


def save_to_database(results):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()

        query = """
            INSERT INTO resultados (data_hora, download, upload, ping, jitter, pacote_perdido, servidor, ip_externo, result_id, result_url)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        values = (
            datetime.now(),
            results["download"],
            results["upload"],
            results["ping"],
            results["jitter"],
            results["pacote_perdido"],
            results["servidor"],
            results["ip_externo"],
            results["result_id"],
            results["result_url"],
        )

        cursor.execute(query, values)
        conn.commit()

        print("Success data save in database!")

        cursor.close()
        conn.close()

    except mysql.connector.Error as e:
        print(f"Error to save in database: {e}")
        sys.exit(1)


if __name__ == "__main__":
    results = test_speed()

    if results:
        save_to_database(results)
    else:
        print("Error to take results")
        sys.exit(1)
