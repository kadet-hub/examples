# Blocking DNS does not stop a socket to a raw IP. socket.getaddrinfo is
# monkeypatched to refuse, then a raw-IP connect is attempted anyway.
import socket
orig = socket.getaddrinfo
def blocked(*a, **k):
    raise OSError("DNS blocked")
socket.getaddrinfo = blocked
try:
    socket.create_connection(("example.com", 80), timeout=2)
except OSError as e:
    print("name lookup blocked:", e)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect(("192.0.2.1", 80))   # TEST-NET-1, raw IP, no DNS
    print("raw-IP connect: established")
except OSError as e:
    print("raw-IP connect reached network, result:", e.__class__.__name__, e)
finally:
    s.close()
