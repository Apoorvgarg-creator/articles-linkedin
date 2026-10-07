# Sources (primary, checked 2026-10-08)

## CNCF status
- OpenTelemetry on CNCF (accepted May 7, 2019; incubating Aug 26, 2021; graduated May 11, 2026): https://www.cncf.io/projects/opentelemetry/
- etcd on CNCF (graduated Nov 24, 2020): https://www.cncf.io/projects/etcd/
- CoreDNS on CNCF (graduated Jan 24, 2019): https://www.cncf.io/projects/coredns/

## Collector concepts and config
- Collector configuration (receivers, processors, exporters, connectors, pipelines; "configuring a processor does not enable it"; separate processor instance per pipeline; localhost default): https://opentelemetry.io/docs/collector/configuration/
- Processor README (data ownership, exclusive vs shared mode, `MutatesData`, recommended processor order, prefer exporter batching): https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/README.md
- Fan-out consumer source ("Clones only to the consumer that needs to mutate the data", sequential calls, combined error): https://github.com/open-telemetry/opentelemetry-collector/blob/main/internal/fanoutconsumer/traces.go
- memory_limiter README (put it first; refuses data when over limit): https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md
- Batch processor README (place after memory_limiter and sampling): https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/batchprocessor/README.md

## Components used in the demo (v0.162.0)
- Filter processor (`trace_conditions`, OTTL, alpha for traces): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/processor/filterprocessor/README.md
- Attributes processor (beta; README says hash is SHA-1): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/processor/attributesprocessor/README.md
- Attribute action code (HASH uses SHA-256 in v0.162.0): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/internal/coreinternal/attraction/attraction.go
- Count connector (alpha; traces -> metrics, per-attribute counts): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/countconnector/README.md
- Collector release v0.162.0 (published 2026-09-29): https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v0.162.0
- OpenTelemetry Collector Builder (ocb): https://opentelemetry.io/docs/collector/extend/ocb/

## Shortlist runner-ups
- CoreDNS plugin chain order defined in plugin.cfg: https://coredns.io/manual/toc/
- etcd API, ErrCompacted on compacted revisions: https://etcd.io/docs/v3.6/learning/api/

## Measured on the box (not from docs)
- otelcol-contrib v0.162.0 linux/amd64 binary size: 407,498,914 bytes.
- `otelcol-contrib validate` exits 0 and the Collector logs no warning when `attributes/scrub` is defined but not in any pipeline (`gotcha-unwired.yaml`).
- `hash` output for `user1@example.com` equals `sha256sum` of that string.
