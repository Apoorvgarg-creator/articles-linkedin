# Prometheus label cardinality demo

See the parent [README.md](../README.md) for results and setup.

```bash
./run.sh            # about 3 minutes
WAIT=300 ./run.sh   # scrape longer before measuring
```

Uses Prometheus 3.15.0 by default (`PROM_VER=...` to change). Binary cached under `bin/`, Python venv under `.venv/`, Prometheus data under `data/`. Output under `out/`.
