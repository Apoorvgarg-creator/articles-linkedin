# One user_id label vs Prometheus: 6 series -> 223,770

Companion code for **The Weekly Commit** newsletter article on Prometheus label cardinality. Read the article: [article.md](./article.md).

A small Python app counts requests with `http_requests_total{route, status}`. Four copies run side by side: one without a `user_id` label, and three with `user_id` for 1,000, 10,000 and 100,000 simulated users. Each copy gets its own Prometheus 3.15.0, so memory can be compared. Two more Prometheus instances test a guardrail (`sample_limit`) and a tempting wrong fix (`labeldrop`).

## Results (real output, Prometheus 3.15.0, linux/amd64, one run of about 150 s, scrape every 15 s)

**1. Same counter, more user_ids: series and memory grow together.**

```
run        users payload_KB samples/scrape head_series   rss_MB heap_inuse_MB  scrape_s
good           0          0              6          11       82            18      0.00
bad1k       1000        325           4302        4307       98            31      0.06
bad10k     10000       1907          25728       25733      142            81      0.39
bad100k   100000      16537         223770      223775      571           461      2.72
```

- `head_series` = the app's series + 5 series Prometheus adds per target (`up`, `scrape_duration_seconds`, ...).
- In this run, each extra series cost about **2 KB of Prometheus heap** ((461 - 18) MiB / 223,764 series). This is one run on one box, not a benchmark. An earlier run with the same settings measured 613 MB RSS at 100k users, so expect variance.
- The good app's `/metrics` page is 418 bytes. At 100k users it is about 16 MB, read every 15 seconds.

**2. How to see it: the TSDB status API names the label (10k run).**

```
GET /api/v1/status/tsdb  -> labelValueCountByLabelName
   user_id 9794
   __name__ 6
   route 3
   status 2
   instance 1
   job 1

count(count by (user_id) (http_requests_total)) -> 9794
count by (__name__) ({__name__=~".+"})          -> http_requests_total 25728
```

`count by (__name__) ({__name__=~".+"})` touches every series. Fine on a laptop, but it can be expensive on a large server. Prefer the TSDB status API there.

**3. Guardrail: `sample_limit: 5000` on the 10k-user app. The scrape fails loudly.**

```
up -> 0
scrape_samples_scraped -> 25728
prometheus_target_scrapes_exceeded_sample_limit_total -> 10
last scrape error -> sample limit exceeded
```

Side note: `prometheus_tsdb_head_series` on that instance read 5005, even though every scrape was rejected. I did not dig into why; treat it as an observation, not a documented behavior.

**4. Wrong quick fix: `labeldrop user_id` at scrape time. Wrong numbers, no error (1k-user app).**

```yaml
metric_relabel_configs:
  - action: labeldrop
    regex: user_id
```

```
count(http_requests_total) bad1k -> 4302   labeldrop -> 6
sum(http_requests_total) bad1k (true total) -> 10100   labeldrop -> 16
up (labeldrop) -> 1
prometheus_target_scrapes_sample_duplicate_timestamp_total -> 0
last scrape error -> (empty)
```

Thousands of series collapse onto 6 label sets and the stored values stop meaning anything. The Prometheus config docs: "Care must be taken with `labeldrop` and `labelkeep` to ensure that metrics are still uniquely labeled once the labels are removed."

**5. The right fix: remove the label in code.**

```python
labels = ["route", "status"]   # 6 series, no matter how many users
```

```
http_requests_total{route="/checkout",status="200"} 849.0
http_requests_total{route="/login",status="200"} 835.0
http_requests_total{route="/checkout",status="500"} 228.0
http_requests_total{route="/login",status="500"} 209.0
http_requests_total{route="/cart",status="200"} 838.0
http_requests_total{route="/cart",status="500"} 241.0
```

Need "which users hit errors"? Log one line per failed request with the user ID, or put it on a trace. Logs and traces are built for one record per request. Metrics are built for a small, fixed set of counters.

## What it costs on a hosted service

Hosted Prometheus-compatible services bill by this. Prices checked 2026-10-21:

- **Grafana Cloud Pro** bills per active series: first 10,000 included, then $6.50 per 1,000 (10,001 to 100,000), $5.90 (100,001 to 200,000), $5.50 (200,001+), plus a $19 platform fee. 223,775 series kept active all month: 90,000 x $6.50/1k + 100,000 x $5.90/1k + 23,775 x $5.50/1k = **about $1,306 a month** at list price, before discounts or reduction features.
- **Amazon Managed Service for Prometheus** bills per sample ingested ($0.90 per 10 million for the first 2 billion), plus storage and queries. More series x more scrapes = more samples.

These are list prices for illustration, not a quote.

## Setup

Requirements: Linux amd64, `curl`, `python3` (3.10+ with `venv`), about 1.5 GB free RAM (in the run above, the 100k-user Prometheus alone used 571 MB). No Docker needed. The script downloads the official Prometheus release tarball and installs `prometheus-client` into a local venv.

```bash
git clone https://github.com/Apoorvgarg-creator/articles-linkedin.git
cd articles-linkedin/cncf/prometheus-label-cardinality/example
./run.sh
```

## Run

`run.sh` does this:

1. Downloads Prometheus **3.15.0** into `example/bin/` on first run (override with `PROM_VER=...`).
2. Starts 4 copies of `app.py` on ports 8001-8004 with `USERS=0, 1000, 10000, 100000`.
3. Starts one Prometheus per app on ports 9091-9094 (scrape every 15 s), a guard instance on 9095 (`sample_limit: 5000` against the 10k app), and a labeldrop instance on 9096 (against the 1k app).
4. Waits `WAIT=150` seconds, then reads each Prometheus's own `/metrics`, the TSDB status API and a few PromQL queries.
5. Writes everything to `example/out/` and stops all processes.

Tweak with env vars: `WAIT=300 ./run.sh`.

Notes:
- The app sets `PROMETHEUS_DISABLE_CREATED_SERIES=True`. By default the Python client adds a `_created` series next to every counter label set, which doubles the count (the first run measured 12 samples instead of 6 for the good app).
- Traffic is simulated with a fixed random seed (3 requests per user at startup, then 50 requests per second), so the series count is repeatable. Not every user hits every route, so 10,000 users made 25,728 series, not 60,000.

## Layout

```
cncf/prometheus-label-cardinality/
  article.md
  README.md
  SOURCES.md
  article-images/      pictures used in the article
  carousel.pdf         the same pictures as a slide deck
  diagrams/            tally-sheets, series-and-memory, find-the-label, fixes (SVG + PNG)
  example/
    app.py             the counter, with or without user_id
    requirements.txt
    run.sh             download, start, scrape, measure, stop
    out/               captured output from the run above
```

## Things to try next

- Add a histogram with `user_id`. Every label set now costs one series per bucket, plus `_sum` and `_count`.
- Set `label_limit` or `label_value_length_limit` and see which scrapes they reject.
- Turn on `extra_scrape_metrics: true` to get `scrape_sample_limit` next to `scrape_samples_scraped`, then alert when a target gets close to its limit.
