# Issue #1: topic shortlist and pick

Audience: practicing developers and tech leads, especially -1 -> 0 builders standing up their first production stack.
Constraint: one genuinely interesting internal mechanism, demoable locally in about 15 minutes (this box has no Docker, so the demo must also run from a plain binary).

## Shortlist (CNCF status verified on cncf.io, 2026-10-08)

| # | Project | CNCF status | Interesting mechanism | 15-minute local demo |
|---|---------|-------------|-----------------------|----------------------|
| 1 | **OpenTelemetry Collector** | Graduated (May 11, 2026; incubating since Aug 26, 2021) | Pipeline graph and the fan-out consumer: one receiver feeds many pipelines, and data is cloned only for pipelines whose processors mutate it (`MutatesData`). Connectors turn one pipeline's output into another's input. | Single binary + a 60-line Go app. Drop health-check spans and hash PII for the "vendor" pipeline while a second pipeline counts every span. |
| 2 | etcd | Graduated (Nov 24, 2020) | MVCC revisions and watch semantics: watch from a past revision to replay history, and hit `ErrCompacted` once that revision is compacted. | Single binary + `etcdctl`. Write keys, watch from rev N, compact, watch again and get the error. |
| 3 | CoreDNS | Graduated (Jan 24, 2019) | The plugin chain order is static and defined in `plugin.cfg` at compile time, not by the order you write plugins in the Corefile. | Single binary + `dig`. Reorder plugins in a Corefile and observe that behavior does not change. |

## Pick: OpenTelemetry Collector (pipelines + fan-out)

Every team that ships a product hits "too much telemetry, some of it PII, and we are locked to one vendor" within months, and the Collector's pipeline graph solves all three without touching app code, so the lesson pays off immediately for -1 -> 0 builders. It is also timely (graduated May 2026) and the internal piece (clone-only-for-mutators fan-out) is small, real, and readable in one Go file, which fits the "interesting piece inside" format.

Runner-ups for later issues: etcd watch + compaction (great for anyone building controllers), CoreDNS static plugin order (great gotcha, narrower audience).
