"""A tiny fake API that counts requests with prometheus_client.

USERS=0      -> labels: route, status          (the right way)
USERS=10000  -> labels: route, status, user_id (the wrong way, on purpose)

Traffic is simulated with a fixed random seed so every run is repeatable.
"""
import os, random, threading, time
from prometheus_client import CollectorRegistry, Counter, start_http_server

USERS = int(os.environ.get("USERS", "0"))
PORT = int(os.environ.get("PORT", "8000"))
REQUESTS_PER_USER = 3

ROUTES = ["/login", "/cart", "/checkout"]
STATUSES = ["200", "200", "200", "200", "500"]  # roughly 1 in 5 requests fail

# Own registry: skip the default process/python metrics so the series count
# you see is only this one counter.
registry = CollectorRegistry()
labels = ["route", "status"] + (["user_id"] if USERS else [])
requests_total = Counter(
    "http_requests_total", "HTTP requests handled", labels, registry=registry
)

rng = random.Random(42)


def one_request():
    lv = {"route": rng.choice(ROUTES), "status": rng.choice(STATUSES)}
    if USERS:
        lv["user_id"] = f"user-{rng.randrange(USERS):06d}"  # WRONG on purpose
    requests_total.labels(**lv).inc()


# Warm up: every user (or 3000 anonymous requests) shows up before the first scrape.
for _ in range(max(USERS, 1000) * REQUESTS_PER_USER):
    one_request()


def keep_traffic_flowing():
    while True:
        for _ in range(50):
            one_request()
        time.sleep(1)


threading.Thread(target=keep_traffic_flowing, daemon=True).start()
start_http_server(PORT, registry=registry)
print(f"app USERS={USERS} listening on :{PORT}", flush=True)
while True:
    time.sleep(3600)
