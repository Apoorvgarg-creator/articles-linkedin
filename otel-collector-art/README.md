# One span in, two truths out: the OpenTelemetry Collector fan-out

Companion code for **The Weekly Commit, OSS Wednesday #1**. Read the article: [article.md](./article.md).

A tiny Go service emits 25 spans (20 health checks, 5 checkouts carrying an email and a bearer token). One OpenTelemetry Collector receiver fans them out to two pipelines:

- `traces/vendor` drops `/healthz` and scrubs PII. This is what you would pay to ship.
- `traces/counts` sees every span and turns them into per-route counts via the `count` connector.

## Results (real output, Collector v0.162.0, linux/amd64)

**1. The vendor gets 5 clean spans, and you still count all 25.**

```
== traces/vendor (what your paid backend receives) ==
spans by route: {'/checkout': 5}
sample /checkout attributes:
  http.route = /checkout
  order.total_cents = 4999
  user.email = b36a83701f1c3191e19722d6f90274bc1b5501fe69ebf33313e440fe4b0fe210

== metrics/counts (fed by the count connector, before filtering) ==
app.span.count{http.route="/checkout"} = 5
app.span.count{http.route="/healthz"} = 20
```

- The filter in `traces/vendor` did not affect `traces/counts`: the fan-out gave the mutating pipeline its own clone.
- `authorization` is gone. `user.email` is an **unsalted SHA-256** (equals `printf 'user1@example.com' | sha256sum`), even though the attributes processor README says SHA-1.

**2. Gotcha: a processor that is configured but not wired into a pipeline does nothing, silently.**

`./run.sh gotcha-unwired.yaml` (same config, `attributes/scrub` removed from the pipeline list only). `otelcol validate` passes and the Collector logs no warning:

```
== traces/vendor (what your paid backend receives) ==
spans by route: {'/checkout': 5}
sample /checkout attributes:
  http.request.header.authorization = Bearer sk_live_not_a_real_token
  http.route = /checkout
  order.total_cents = 4999
  user.email = user1@example.com
```

## Setup

Requirements: Linux or macOS (amd64/arm64), `curl`, `python3`, and Go 1.21+ (Go will fetch the toolchain version in `go.mod` automatically). No Docker needed.

```bash
git clone https://github.com/Apoorvgarg-creator/articles-linkedin.git
cd articles-linkedin/otel-collector-art/example
```

## Run

```bash
./run.sh                       # main demo
./run.sh gotcha-unwired.yaml   # the silent-misconfig gotcha
```

`run.sh` downloads `otelcol-contrib` v0.162.0 into `example/bin/` on first run (about 407 MB unpacked, override with `OTELCOL_VERSION=...`), validates the config, starts the Collector on `localhost:4318`, runs the Go app, then prints what each pipeline exported via `summarize.py`. Raw exporter output lands in `example/out/` (`vendor.json`, `counts.json`, `collector.log`).

## Layout

```
otel-collector-art/
  article.md            the newsletter piece
  diagrams/             fanout-graph.png, span-journey.png
  SOURCES.md            primary sources for every claim
  example/
    otelcol.yaml        1 receiver -> 2 trace pipelines + count connector -> 1 metrics pipeline
    gotcha-unwired.yaml same, with attributes/scrub defined but not in the pipeline
    app/main.go         Go "checkout-api" emitting spans over OTLP/HTTP
    run.sh              download, validate, run, summarize
    summarize.py        reads out/*.json and prints per-pipeline results
```

## Things to try next

- Swap the order to `[memory_limiter, attributes/scrub, filter/drop_healthz]` and add a filter on the raw `user.email` value. Watch it stop matching.
- Point `file/vendor` at a real backend by replacing it with an `otlp_http` exporter.
- Change `action: hash` to `action: delete` for `user.email` if you never need to group by user.
