# Sources (primary, checked 2026-10-21)

## CNCF status
- Prometheus on CNCF (incubating May 9, 2016; graduated Aug 9, 2018): https://www.cncf.io/projects/prometheus/

## Labels, series, cardinality
- Data model (a series is identified by metric name + labels): https://prometheus.io/docs/concepts/data_model/
- Naming best practices, labels caution ("every unique combination of key-value label pairs represents a new time series ... Do not use labels to store dimensions with high cardinality ... such as user IDs"): https://prometheus.io/docs/practices/naming/#labels
- Instrumentation, "Do not overuse labels" (RAM/CPU/disk/network cost per labelset; keep cardinality below 10; investigate over 100): https://prometheus.io/docs/practices/instrumentation/#do-not-overuse-labels
- Jobs and instances (`up` is 1 if healthy, 0 if the scrape failed): https://prometheus.io/docs/concepts/jobs_instances/

## Config and API (v3.15.0)
- `sample_limit`, `label_limit`, `extra_scrape_metrics`, and the `labeldrop` uniqueness warning: https://github.com/prometheus/prometheus/blob/v3.15.0/docs/configuration/configuration.md
- TSDB stats API (`/api/v1/status/tsdb`, `labelValueCountByLabelName`): https://github.com/prometheus/prometheus/blob/v3.15.0/docs/querying/api.md

## Client library
- Python client, `_created` series and `PROMETHEUS_DISABLE_CREATED_SERIES`: https://prometheus.github.io/client_python/instrumenting/
- prometheus-client 0.26.0 on PyPI: https://pypi.org/project/prometheus-client/0.26.0/

## Pricing (list prices, checked 2026-10-21)
- Grafana Cloud pricing (active series tiers): https://grafana.com/pricing/
- Amazon Managed Service for Prometheus pricing (per sample ingested): https://aws.amazon.com/prometheus/pricing/

## Release used in the demo
- Prometheus v3.15.0 (2026-09-25, revision 5241a27): https://github.com/prometheus/prometheus/releases/tag/v3.15.0

## Measured locally (not from docs)
- Prometheus 3.15.0 linux/amd64 (go1.27.1), prometheus-client 0.26.0, Python 3, one box, scrape_interval 15s, about 150 s of scraping.
- Series 6 / 4,302 / 25,728 / 223,770 for 0 / 1k / 10k / 100k users; RSS 82 / 98 / 142 / 571 MB; heap in use 18 / 31 / 81 / 461 MB; scrape 0.00 / 0.06 / 0.39 / 2.72 s.
- TSDB status on the 10k run: user_id 9794 values.
- sample_limit 5000: up 0, "sample limit exceeded".
- labeldrop user_id on the 1k app: 6 series, sum 16 vs true 10,100, no scrape error.
- Artifacts: example/out/summary.txt, tsdb-status-*.json, metrics-good.txt, metrics-bad10k-head.txt.
