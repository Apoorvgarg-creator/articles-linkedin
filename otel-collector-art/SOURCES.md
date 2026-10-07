# Sources (primary, checked 2026-10-08)

## CNCF status
- OpenTelemetry on CNCF (accepted May 7, 2019; incubating Aug 26, 2021; graduated May 11, 2026): https://www.cncf.io/projects/opentelemetry/
- CNCF graduation announcement (published May 21, 2026): https://www.cncf.io/announcements/2026/05/21/cloud-native-computing-foundation-announces-opentelemetrys-graduation-solidifying-status-as-the-de-facto-observability-standard/

## Collector concepts and config
- Collector configuration (receivers, processors, exporters, connectors, pipelines; "configuring a processor does not enable it"; separate processor instance per pipeline; localhost default): https://opentelemetry.io/docs/collector/configuration/
- Processor README (data ownership, exclusive vs shared mode, `MutatesData`, recommended processor order, prefer exporter batching): https://github.com/open-telemetry/opentelemetry-collector/blob/v0.162.0/processor/README.md
- Fan-out consumer source ("Clones only to the consumer that needs to mutate the data", last mutator gets the original only when no read-only consumer exists, read-only marking only with 2+ read-only consumers, sequential calls, combined error): https://github.com/open-telemetry/opentelemetry-collector/blob/v0.162.0/internal/fanoutconsumer/traces.go
- Pipeline capabilities node (a pipeline mutates if any processor in it mutates): https://github.com/open-telemetry/opentelemetry-collector/blob/v0.162.0/service/internal/graph/graph.go
- memory_limiter factory (one shared limiter per config across pipelines; `MutatesData: false`): https://github.com/open-telemetry/opentelemetry-collector/blob/v0.162.0/processor/memorylimiterprocessor/factory.go
- memory_limiter README (put it first; refuses data when over limit): https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md
- Batch processor README (place after memory_limiter and sampling): https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/batchprocessor/README.md

## Components used in the demo (v0.162.0)
- Filter processor (`trace_conditions`, OTTL, alpha for traces): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/processor/filterprocessor/README.md
- Attributes processor (beta; README says hash is SHA-1): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/processor/attributesprocessor/README.md
- Attribute action code (HASH calls sha2Hasher in v0.162.0): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/internal/coreinternal/attraction/attraction.go
- Hasher (crypto/sha256, no salt): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/internal/coreinternal/attraction/hasher.go
- Count connector (alpha; traces -> metrics, per-attribute counts; `MutatesData: false`): https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.162.0/connector/countconnector/README.md
- Collector release v0.162.0 (published 2026-09-29): https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v0.162.0
- OpenTelemetry Collector Builder (ocb): https://opentelemetry.io/docs/collector/extend/ocb/
- Contrib distribution contents (all core and contrib components at alpha or higher; recommends a custom build for production): https://github.com/open-telemetry/opentelemetry-collector-releases/blob/v0.162.0/distributions/otelcol-contrib/README.md


## Measured locally (not from docs)
- otelcol-contrib v0.162.0 linux/amd64 binary size: 407,498,914 bytes unpacked (407.5 MB, which `ls -lh` shows as 389M because it uses MiB). The release tarball `otelcol-contrib_0.162.0_linux_amd64.tar.gz` is 112,285,869 bytes (about 112 MB).
- `otelcol-contrib validate` exits 0 and the Collector logs no warning, even with `service.telemetry.logs.level=debug`, when `attributes/scrub` is defined but not in any pipeline (`gotcha-unwired.yaml`).
- `hash` output for `user1@example.com` equals `sha256sum` of that string.
