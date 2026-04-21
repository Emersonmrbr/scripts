#!/usr/bin/env python3

import subprocess
import json
import mysql.connector
from datetime import datetime
import sys
import time
import re

DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 21503,
    'user': 'speedtest_user',
    'password': '',
    'database': 'speedtest'
}

def test_speed_simet():
    """Executa teste usando SIMET da Anatel via Docker"""
    try:
        print(f"\n{'='*50}")
        print(f"Iniciando teste SIMET em {datetime.now()}")
        print(f"{'='*50}")
        
        # Executar teste TCPBW (TCP Bandwidth) do SIMET
        result = subprocess.run(
            [
                'docker', 'run', '--rm',
                '--network', 'host',
                '--cap-add', 'NET_ADMIN',
                '--cap-add', 'NET_RAW',
                '-e', 'SIMET_RUN_TEST=TCPBW',
                'simet-ma:local'
            ],
            capture_output=True,
            text=True,
            timeout=180
        )
        
        output = result.stdout + result.stderr
        print(f"\nOutput SIMET (últimas linhas):")
        print('\n'.join(output.split('\n')[-20:]))
        
        # Extrair dados do output
        # Procurar por padrões no output do SIMET
        download = 0
        upload = 0
        ping = 0
        
        # O SIMET pode retornar dados em diferentes formatos
        # Vamos tentar extrair do texto
        
        # Padrão 1: Procurar por valores de velocidade
        download_match = re.search(r'download[:\s]+([0-9.]+)\s*(?:Mbps|Mbit/s|MB/s)', output, re.IGNORECASE)
        upload_match = re.search(r'upload[:\s]+([0-9.]+)\s*(?:Mbps|Mbit/s|MB/s)', output, re.IGNORECASE)
        
        # Padrão 2: Procurar por bandwidth
        if not download_match:
            download_match = re.search(r'(?:downstream|down).*?([0-9.]+)\s*(?:Mbps|Mbit)', output, re.IGNORECASE)
        if not upload_match:
            upload_match = re.search(r'(?:upstream|up).*?([0-9.]+)\s*(?:Mbps|Mbit)', output, re.IGNORECASE)
        
        if download_match:
            download = float(download_match.group(1))
        if upload_match:
            upload = float(upload_match.group(1))
        
        # Extrair latência se disponível
        ping_match = re.search(r'(?:latency|rtt|ping)[:\s]+([0-9.]+)\s*ms', output, re.IGNORECASE)
        if ping_match:
            ping = float(ping_match.group(1))
        
        # Extrair server peer
        server_match = re.search(r'measurement peer:\s*(.+)', output)
        servidor = server_match.group(1).strip() if server_match else 'SIMET NIC.br'
        
        # Se não conseguimos extrair velocidades do output, 
        # vamos fazer um teste simples de download
        if download == 0:
            print("\nNão encontrei velocidades no output, usando método alternativo...")
            download = test_download_speed_simple()
        
        # IP externo
        try:
            import requests
            ip_externo = requests.get('https://api.ipify.org', timeout=10).text.strip()
        except:
            ip_externo = 'N/A'
        
        print(f"\n✓ Download: {download:.2f} Mbps")
        print(f"✓ Upload: {upload:.2f} Mbps")
        print(f"✓ Ping: {ping:.2f} ms")
        print(f"✓ Servidor: {servidor}")
        
        return {
            'download': download,
            'upload': upload,
            'ping': ping,
            'servidor': servidor,
            'ip_externo': ip_externo
        }
        
    except subprocess.TimeoutExpired:
        print("❌ Timeout no teste SIMET (>180s)")
        return None
    except Exception as e:
        print(f"❌ Erro no teste SIMET: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_download_speed_simple():
    """Teste simples de download contra servidor SIMET"""
    try:
        import requests
        url = 'http://200.160.4.53/speed/random4M.bin'
        
        start = time.time()
        response = requests.get(url, timeout=30)
        elapsed = time.time() - start
        
        # bytes para Mbps
        mbps = (len(response.content) * 8) / (elapsed * 1000000)
        return mbps
    except:
        return 0

def test_speed_speedtest():
    """Teste usando Speedtest CLI (Ookla)"""
    try:
        print(f"\n{'='*50}")
        print(f"Iniciando teste Speedtest em {datetime.now()}")
        print(f"{'='*50}")
        
        result = subprocess.run(
            ['speedtest', '--accept-license', '--accept-gdpr', '-f', 'json'],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode != 0:
            print(f"❌ Erro Speedtest: {result.stderr}")
            return None
        
        data = json.loads(result.stdout)
        
        download = data['download']['bandwidth'] / 125000
        upload = data['upload']['bandwidth'] / 125000
        ping = data['ping']['latency']
        servidor = f"{data['server']['name']} - {data['server']['location']}"
        ip_externo = data['interface']['externalIp']
        
        print(f"✓ Download: {download:.2f} Mbps")
        print(f"✓ Upload: {upload:.2f} Mbps")
        print(f"✓ Ping: {ping:.2f} ms")
        print(f"✓ Servidor: {servidor}")
        
        return {
            'download': download,
            'upload': upload,
            'ping': ping,
            'servidor': servidor,
            'ip_externo': ip_externo
        }
        
    except Exception as e:
        print(f"❌ Erro no teste Speedtest: {e}")
        import traceback
        traceback.print_exc()
        return None

def save_simet_to_database(results):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Verificar se a coluna 'ferramenta' existe
        try:
            cursor.execute("SHOW COLUMNS FROM resultados LIKE 'ferramenta'")
            if cursor.fetchone() is None:
                cursor.execute("ALTER TABLE resultados ADD COLUMN ferramenta VARCHAR(50) DEFAULT 'SIMET'")
                conn.commit()
        except:
            pass
        
        query = """
            INSERT INTO resultados (data_hora, download, upload, ping, servidor, ip_externo, ferramenta)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        values = (
            datetime.now(),
            results['download'],
            results['upload'],
            results['ping'],
            results['servidor'],
            results['ip_externo'],
            'SIMET'
        )
        
        cursor.execute(query, values)
        conn.commit()
        
        print("✓ Dados SIMET salvos na tabela 'resultados'!")
        
        cursor.close()
        conn.close()
        return True
        
    except mysql.connector.Error as e:
        print(f"❌ Erro ao salvar SIMET no banco: {e}")
        return False

def save_speedtest_to_database(results):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Criar tabela se não existir
        try:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS resultados_speedtest (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    data_hora DATETIME NOT NULL,
                    download DECIMAL(10,2) NOT NULL,
                    upload DECIMAL(10,2) NOT NULL,
                    ping DECIMAL(10,2) NOT NULL,
                    servidor VARCHAR(255),
                    ip_externo VARCHAR(50),
                    INDEX idx_data_hora (data_hora)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """)
            conn.commit()
        except:
            pass
        
        query = """
            INSERT INTO resultados_speedtest (data_hora, download, upload, ping, servidor, ip_externo)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        values = (
            datetime.now(),
            results['download'],
            results['upload'],
            results['ping'],
            results['servidor'],
            results['ip_externo']
        )
        
        cursor.execute(query, values)
        conn.commit()
        
        print("✓ Dados Speedtest salvos na tabela 'resultados_speedtest'!")
        
        cursor.close()
        conn.close()
        return True
        
    except mysql.connector.Error as e:
        print(f"❌ Erro ao salvar Speedtest no banco: {e}")
        return False

if __name__ == "__main__":
    print(f"\n{'#'*60}")
    print(f"# Monitoramento de Velocidade - Dual Test")
    print(f"# SIMET (NIC.br - Oficial Anatel) + Speedtest (Ookla)")
    print(f"# Início: {datetime.now()}")
    print(f"{'#'*60}")
    
    success_count = 0
    
    # Teste SIMET (oficial Anatel)
    results_simet = test_speed_simet()
    if results_simet:
        if save_simet_to_database(results_simet):
            success_count += 1
    else:
        print("⚠️  SIMET não retornou resultados")
    
    time.sleep(5)
    
    # Teste Speedtest
    results_speedtest = test_speed_speedtest()
    if results_speedtest:
        if save_speedtest_to_database(results_speedtest):
            success_count += 1
    else:
        print("⚠️  Speedtest não retornou resultados")
    
    print(f"\n{'#'*60}")
    print(f"# Resumo: {success_count}/2 testes salvos com sucesso")
    print(f"# Fim: {datetime.now()}")
    print(f"{'#'*60}\n")
    
    sys.exit(0 if success_count > 0 else 1)