#!/usr/bin/env bash
# Downloads the Collector (contrib distribution), starts it, runs the demo app,
# then prints what each pipeline exported. Linux and macOS, amd64 or arm64.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${OTELCOL_VERSION:-0.162.0}"
CONFIG="${1:-otelcol.yaml}"
BIN="./bin/otelcol-contrib"

if [ ! -x "$BIN" ]; then
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"; [ "$ARCH" = "x86_64" ] && ARCH=amd64; [ "$ARCH" = "aarch64" ] && ARCH=arm64
  TAR="otelcol-contrib_${VERSION}_${OS}_${ARCH}.tar.gz"
  echo "downloading $TAR"
  mkdir -p bin
  curl -fsSL -o "bin/$TAR" "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${VERSION}/${TAR}"
  tar -xzf "bin/$TAR" -C bin otelcol-contrib
  rm "bin/$TAR"
fi

"$BIN" --version
"$BIN" validate --config="$CONFIG"

rm -rf out && mkdir -p out
"$BIN" --config="$CONFIG" > out/collector.log 2>&1 &
COL_PID=$!
trap 'kill $COL_PID 2>/dev/null || true' EXIT

# wait for the OTLP/HTTP port
for _ in $(seq 1 50); do
  (exec 3<>/dev/tcp/127.0.0.1/4318) 2>/dev/null && break
  sleep 0.2
done

(cd app && go run .)

sleep 2                      # file exporter flushes every second by default
kill $COL_PID; wait $COL_PID 2>/dev/null || true
trap - EXIT

echo
python3 summarize.py
