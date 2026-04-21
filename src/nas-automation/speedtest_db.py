#!/usr/bin/env python3

import speedtest
import mysql.connector
from datetime import datetime
import sys

# Database settings
DB_CONFIG = {
    'host': 'localhost',
    'port': 21503,
    'user': 'speedtest_user',
    'password': '',
    'database': 'speedtest'
}

def test_speed():
    try:
        print(f"Start test in {datetime.now()}")
        
        # Create speedtest object
        st = speedtest.Speedtest()
        
        # Take best server
        st.get_best_server()
        servidor = st.results.server['sponsor'] + ' - ' + st.results.server['name']
        
        # Run tests
        print("Testing download...")
        download = st.download() / 1_000_000  # Mbps convert
        
        print("Testing upload...")
        upload = st.upload() / 1_000_000  # Mbps convert
        
        ping = st.results.ping
        
        # Take IP outside
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
        
    except Exception as e:
        print(f"Error test: {e}")
        return None

def save_to_database(results):
    try:
        # Conect to database
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Insert data
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
        print(f"Error at save data in database: {e}")
        sys.exit(1)

if __name__ == "__main__":
    results = test_speed()
    
    if results:
        save_to_database(results)
    else:
        print("Error to take results")
        sys.exit(1)