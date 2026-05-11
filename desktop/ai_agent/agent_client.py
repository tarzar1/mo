"""Cliente del Agente de Vision
Envia comandos al servicio en segundo plano (localhost:9999)"""

import socket, sys

PORT = 9999

def send(cmd):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect(('127.0.0.1', PORT))
        s.send(cmd.encode('utf-8'))
        response = b''
        while True:
            try:
                chunk = s.recv(4096)
                if not chunk: break
                response += chunk
            except socket.timeout:
                break
        s.close()
        return response.decode('utf-8', 'ignore')
    except ConnectionRefusedError:
        return "ERROR: Agente no esta corriendo. Inicia: python agent_live_service.py"
    except Exception as e:
        return f"ERROR: {e}"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso:   python agent_client.py <comando>")
        print()
        print("Ejemplos:")
        print("  python agent_client.py mode control")
        print("  python agent_client.py ver")
        print("  python agent_client.py click Chrome")  
        print("  python agent_client.py escribir hola")
        print("  python agent_client.py status")
        print("  python agent_client.py help")
        sys.exit(1)

    cmd = ' '.join(sys.argv[1:])
    resp = send(cmd)
    if resp:
        print(resp)
