#!/usr/bin/env bash
# One user_id label vs Prometheus memory. No Docker needed.
# Starts 4 copies of app.py (0, 1k, 10k, 100k users) and one Prometheus per app,
# plus a 5th Prometheus that guards the 10k app with sample_limit.
set -euo pipefail
cd "$(dirname "$0")"
PROM_VER="${PROM_VER:-3.15.0}"
WAIT="${WAIT:-150}"           # seconds to let Prometheus scrape before measuring
OUT=out; rm -rf "$OUT" data; mkdir -p "$OUT" data bin

# 1. Prometheus binary (official release tarball)
if [ ! -x bin/prometheus ]; then
  curl -sSL -o /tmp/prom.tgz "https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz"
  tar xzf /tmp/prom.tgz -C /tmp
  cp "/tmp/prometheus-${PROM_VER}.linux-amd64/prometheus" "/tmp/prometheus-${PROM_VER}.linux-amd64/promtool" bin/
fi
bin/prometheus --version | head -1 | tee "$OUT/version.txt"

# 2. Python app
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv && .venv/bin/pip -q install -r requirements.txt; fi

PIDS=()
cleanup() { kill "${PIDS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# name users app_port prom_port extra_scrape_config
RUNS=("good 0 8001 9091" "bad1k 1000 8002 9092" "bad10k 10000 8003 9093" "bad100k 100000 8004 9094")

for r in "${RUNS[@]}"; do
  set -- $r
  PROMETHEUS_DISABLE_CREATED_SERIES=True USERS=$2 PORT=$3 .venv/bin/python app.py >"$OUT/app-$1.log" 2>&1 & PIDS+=($!)
done
# wait for apps to finish warm-up
for r in "${RUNS[@]}"; do set -- $r; until curl -sf "localhost:$3/metrics" >/dev/null; do sleep 1; done; done

start_prom() { # name app_port prom_port extra
  mkdir -p "data/$1"
  cat > "data/$1/prometheus.yml" <<YML
global:
  scrape_interval: 15s
  scrape_timeout: 10s
scrape_configs:
  - job_name: api
    static_configs:
      - targets: ["localhost:$2"]
$4
YML
  bin/prometheus --config.file="data/$1/prometheus.yml" --storage.tsdb.path="data/$1/tsdb" \
    --web.listen-address="127.0.0.1:$3" >"$OUT/prom-$1.log" 2>&1 & PIDS+=($!)
}
for r in "${RUNS[@]}"; do set -- $r; start_prom "$1" "$3" "$4" ""; done
# guardrail: same 10k-user app, but refuse scrapes with more than 5000 samples
start_prom guard 8003 9095 "    sample_limit: 5000"
# wrong quick fix: strip user_id at scrape time on the 1k app
start_prom labeldrop 8002 9096 "    metric_relabel_configs:
      - action: labeldrop
        regex: user_id"

echo "scraping for ${WAIT}s..."; sleep "$WAIT"

q() { curl -s "localhost:$1/api/v1/query" --data-urlencode "query=$2" | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "none")'; }
self() { curl -s "localhost:$1/metrics" | awk -v m="$2" '$1==m {print $2}'; }

printf "%-8s %7s %10s %14s %11s %8s %13s %9s\n" run users payload_KB samples/scrape head_series rss_MB heap_inuse_MB scrape_s | tee "$OUT/summary.txt"
for r in "${RUNS[@]}"; do
  set -- $r
  payload=$(curl -s "localhost:$3/metrics" | wc -c)
  samples=$(q "$4" 'scrape_samples_scraped')
  dur=$(q "$4" 'scrape_duration_seconds')
  series=$(self "$4" prometheus_tsdb_head_series)
  rss=$(self "$4" process_resident_memory_bytes)
  heap=$(self "$4" go_memstats_heap_inuse_bytes)
  python3 -c "import sys; n,u,p,s,se,r,h,d=sys.argv[1:]; print(f'{n:<8} {u:>7} {int(p)/1024:>10.0f} {s:>14} {se:>11} {float(r)/1048576:>8.0f} {float(h)/1048576:>13.0f} {float(d):>9.2f}')" \
    "$1" "$2" "$payload" "$samples" "$series" "$rss" "$heap" "$dur" | tee -a "$OUT/summary.txt"
  curl -s "localhost:$4/api/v1/status/tsdb" > "$OUT/tsdb-status-$1.json"
done

{
  echo; echo "# how to SEE it on the 10k run"
  echo "count by (__name__) ({__name__=~\".+\"})  ->"; curl -s "localhost:9093/api/v1/query" --data-urlencode 'query=count by (__name__) ({__name__=~".+"})' | python3 -c 'import json,sys; [print("  ",x["metric"]["__name__"],x["value"][1]) for x in sorted(json.load(sys.stdin)["data"]["result"],key=lambda x:-int(x["value"][1]))]'
  echo "count(count by (user_id) (http_requests_total)) -> $(q 9093 'count(count by (user_id) (http_requests_total))')"
  echo "TSDB status labelValueCountByLabelName ->"; python3 -c 'import json; d=json.load(open("out/tsdb-status-bad10k.json"))["data"]; [print("  ",x["name"],x["value"]) for x in d["labelValueCountByLabelName"]]'
  echo; echo "# guardrail: sample_limit 5000 on the 10k app"
  echo "up -> $(q 9095 'up')"
  echo "scrape_samples_scraped -> $(q 9095 'scrape_samples_scraped')"
  echo "prometheus_target_scrapes_exceeded_sample_limit_total -> $(self 9095 prometheus_target_scrapes_exceeded_sample_limit_total)"
  echo "head_series -> $(self 9095 prometheus_tsdb_head_series)"
  echo "last scrape error ->"; curl -s localhost:9095/api/v1/targets | python3 -c 'import json,sys; print("  ",json.load(sys.stdin)["data"]["activeTargets"][0]["lastError"])'
  echo; echo "# wrong quick fix: labeldrop user_id on the 1k app (compare with bad1k, same app, same moment)"
  echo "count(http_requests_total) bad1k -> $(q 9092 'count(http_requests_total)')   labeldrop -> $(q 9096 'count(http_requests_total)')"
  echo "sum(http_requests_total) bad1k (true total) -> $(q 9092 'sum(http_requests_total)')   labeldrop -> $(q 9096 'sum(http_requests_total)')"
  echo "up (labeldrop) -> $(q 9096 'up')"
  echo "prometheus_target_scrapes_sample_duplicate_timestamp_total -> $(self 9096 prometheus_target_scrapes_sample_duplicate_timestamp_total)"
  echo "last scrape error ->"; curl -s localhost:9096/api/v1/targets | python3 -c 'import json,sys; print("  ",json.load(sys.stdin)["data"]["activeTargets"][0]["lastError"])'
} | tee -a "$OUT/summary.txt"
