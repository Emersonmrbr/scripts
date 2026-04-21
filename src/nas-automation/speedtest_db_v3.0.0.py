#!/usr/bin/env python3

import speedtest
import mysql.connector
from datetime import datetime
import sys
import time

# Configurações do banco de dados
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 21503,
    'user': 'speedtest_user',
    'password': '',
    'database': 'speedtest'
}

def test_speed():
    try:
        print(f"Start test in {datetime.now()}")
        
        # Criar objeto speedtest com configurações customizadas
        st = speedtest.Speedtest(secure=True)
        
        # Usar um servidor específico mais confiável
        st.get_servers()
        
        # Obter melhor servidor
        st.get_best_server()
        servidor = st.results.server['sponsor'] + ' - ' + st.results.server['name']
        
        print(f"Using server: {servidor}")
        
        # Aguardar um pouco antes do download
        time.sleep(2)
        
        # Realizar teste de download
        print("Testing download...")
        download = st.download() / 1_000_000  # Converter para Mbps
        
        # Aguardar antes do upload
        time.sleep(2)
        
        # Realizar teste de upload
        print("Testing upload...")
        upload = st.upload() / 1_000_000  # Converter para Mbps
        
        ping = st.results.ping
        
        # Obter IP externo
        ip_externo = st.results.client['ip']
        
        print(f"Download: {download:.2f} Mbps")
        print(f"Upload: {upload:.2f} Mbps")
        print(f"Ping: {ping:.2f} ms")
        
        return {
            'download': download,
            'upload': upload,
            'ping': ping,
            'servidor': servidor,
            'ip_externo': ip_externo
        }
        
    except speedtest.ConfigRetrievalError:
        print("Error: Cannot retrieve speedtest configuration. Check your internet connection.")
        return None
    except speedtest.NoMatchedServers:
        print("Error: No matched servers found.")
        return None
    except Exception as e:
        print(f"Error test: {e}")
        return None

def save_to_database(results):
    try:
        # Conectar ao banco
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Inserir dados
        query = """
            INSERT INTO resultados (data_hora, download, upload, ping, servidor, ip_externo)
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
        
        print("Success data save in database!")
        
        cursor.close()
        conn.close()
        
    except mysql.connector.Error as e:
        print(f"Error to save in database: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Adicionar delay aleatório para evitar padrões de requisição
    import random
    delay = random.randint(5, 30)
    print(f"Waiting {delay} seconds before starting...")
    time.sleep(delay)
    
    results = test_speed()
    
    if results:
        save_to_database(results)
    else:
        print("Error to take results")
        sys.exit(1)