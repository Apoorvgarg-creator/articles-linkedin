#!/usr/bin/env bash
# Demo: etcd watch from a past revision, then hit ErrCompacted after compaction.
# No Docker. Downloads etcd linux/amd64 once into example/bin/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/bin"
OUT="$ROOT/out"
DATA="$ROOT/data"
ETCD_VER="${ETCD_VER:-v3.7.2}"
ENDPOINT="${ENDPOINT:-http://127.0.0.1:2379}"
CLIENT_PORT="${CLIENT_PORT:-2379}"
PEER_PORT="${PEER_PORT:-2380}"

mkdir -p "$BIN" "$OUT"
rm -rf "$DATA"
mkdir -p "$DATA"
# Keep prior out/ only until we rewrite; wipe for a clean run
find "$OUT" -mindepth 1 -delete 2>/dev/null || true

download_etcd() {
  if [[ -x "$BIN/etcd" && -x "$BIN/etcdctl" ]]; then
    local ver
    ver="$("$BIN/etcd" --version 2>/dev/null | head -1 || true)"
    if echo "$ver" | grep -q "${ETCD_VER#v}"; then
      return 0
    fi
  fi
  echo "== downloading etcd ${ETCD_VER} linux/amd64 =="
  local url="https://storage.googleapis.com/etcd/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/etcd.tgz"
  tar xzf "$tmp/etcd.tgz" -C "$tmp"
  cp "$tmp/etcd-${ETCD_VER}-linux-amd64/etcd" "$tmp/etcd-${ETCD_VER}-linux-amd64/etcdctl" "$BIN/"
  chmod +x "$BIN/etcd" "$BIN/etcdctl"
  rm -rf "$tmp"
}

# Strip noisy client warn lines from captured tool output
strip_noise() {
  grep -v 'unrecognized environment variable' | grep -v '"logger":"etcd-client"' || true
}

cleanup() {
  if [[ -n "${ETCD_PID:-}" ]] && kill -0 "$ETCD_PID" 2>/dev/null; then
    kill "$ETCD_PID" 2>/dev/null || true
    wait "$ETCD_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

download_etcd

ETCDCTL=("$BIN/etcdctl" --endpoints="$ENDPOINT")

echo "== starting single-node etcd ${ETCD_VER} =="
"$BIN/etcd" \
  --name demo \
  --data-dir "$DATA" \
  --listen-client-urls "http://127.0.0.1:${CLIENT_PORT}" \
  --advertise-client-urls "http://127.0.0.1:${CLIENT_PORT}" \
  --listen-peer-urls "http://127.0.0.1:${PEER_PORT}" \
  --initial-advertise-peer-urls "http://127.0.0.1:${PEER_PORT}" \
  --initial-cluster "demo=http://127.0.0.1:${PEER_PORT}" \
  --initial-cluster-token etcd-demo \
  --initial-cluster-state new \
  >"$OUT/etcd.log" 2>&1 &
ETCD_PID=$!

for _ in $(seq 1 50); do
  if "${ETCDCTL[@]}" endpoint health >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
"${ETCDCTL[@]}" endpoint health | tee "$OUT/health.txt"
"$BIN/etcd" --version | tee "$OUT/version.txt"
"${ETCDCTL[@]}" version | tee -a "$OUT/version.txt"

echo
echo "== step 1: write keys (each put bumps the cluster revision) =="
"${ETCDCTL[@]}" put /demo/pod/a running | tee "$OUT/puts.txt"
REV_A="$("${ETCDCTL[@]}" get /demo/pod/a --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)["header"]["revision"])')"
echo "rev after put a: $REV_A" | tee -a "$OUT/puts.txt"

"${ETCDCTL[@]}" put /demo/pod/b pending | tee -a "$OUT/puts.txt"
REV_B="$("${ETCDCTL[@]}" get /demo/pod/b --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)["header"]["revision"])')"
echo "rev after put b: $REV_B" | tee -a "$OUT/puts.txt"

"${ETCDCTL[@]}" put /demo/pod/a ready | tee -a "$OUT/puts.txt"
REV_A2="$("${ETCDCTL[@]}" get /demo/pod/a --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)["header"]["revision"])')"
echo "rev after update a: $REV_A2" | tee -a "$OUT/puts.txt"

CURRENT="$("${ETCDCTL[@]}" endpoint status --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["Status"]["header"]["revision"])')"
echo "current cluster revision: $CURRENT" | tee -a "$OUT/puts.txt"
echo "$REV_A" > "$OUT/watch_from_rev.txt"
echo "$CURRENT" > "$OUT/current_rev.txt"

echo
echo "== step 2: watch from revision $REV_A (history still present) =="
set +e
timeout 2s "${ETCDCTL[@]}" watch --rev="$REV_A" --prefix /demo/pod/ >"$OUT/watch_ok.raw" 2>&1
WATCH_OK_RC=$?
set -e
strip_noise < "$OUT/watch_ok.raw" | tee "$OUT/watch_ok.txt"
echo "(watch exited rc=$WATCH_OK_RC after timeout; that is expected)" | tee -a "$OUT/watch_ok.txt"

EVENT_COUNT="$(grep -c '^PUT$' "$OUT/watch_ok.txt" || true)"
echo "events_seen=$EVENT_COUNT" | tee "$OUT/event_count.txt"

echo
echo "== step 3: more writes, then compact past the watch-from revision =="
"${ETCDCTL[@]}" put /demo/pod/c starting | tee "$OUT/compact.txt"
"${ETCDCTL[@]}" put /demo/pod/b ready | tee -a "$OUT/compact.txt"
AFTER_WRITES="$("${ETCDCTL[@]}" endpoint status --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["Status"]["header"]["revision"])')"
echo "revision before compact: $AFTER_WRITES" | tee -a "$OUT/compact.txt"

"${ETCDCTL[@]}" compact "$AFTER_WRITES" | tee -a "$OUT/compact.txt"
echo "$AFTER_WRITES" > "$OUT/compact_rev.txt"

echo
echo "== step 4: WRONG: resume watch from old revision $REV_A =="
set +e
timeout 3s "${ETCDCTL[@]}" watch --rev="$REV_A" --prefix /demo/pod/ >"$OUT/watch_compacted.raw" 2>&1
WATCH_BAD_RC=$?
set -e
strip_noise < "$OUT/watch_compacted.raw" | tee "$OUT/watch_compacted.txt"
echo "(watch exited rc=$WATCH_BAD_RC)" | tee -a "$OUT/watch_compacted.txt"

echo
echo "== step 5: get --rev=$REV_A also fails the same way =="
set +e
"${ETCDCTL[@]}" get --rev="$REV_A" /demo/pod/a >"$OUT/get_compacted.raw" 2>&1
GET_RC=$?
set -e
strip_noise < "$OUT/get_compacted.raw" | tee "$OUT/get_compacted.txt"
echo "(get exited rc=$GET_RC)" | tee -a "$OUT/get_compacted.txt"

echo
echo "== step 6: RIGHT: re-list current state, then watch from a non-compacted revision =="
"${ETCDCTL[@]}" get --prefix /demo/pod/ | tee "$OUT/relist.txt"
CURRENT2="$("${ETCDCTL[@]}" endpoint status --write-out=json | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["Status"]["header"]["revision"])')"
echo "resume_from_rev=$CURRENT2" | tee "$OUT/resume_rev.txt"

set +e
timeout 2s "${ETCDCTL[@]}" watch --rev="$AFTER_WRITES" --prefix /demo/pod/ >"$OUT/watch_resume.raw" 2>&1
RESUME_RC=$?
set -e
strip_noise < "$OUT/watch_resume.raw" | tee "$OUT/watch_resume.txt"
echo "(resume watch exited rc=$RESUME_RC)" | tee -a "$OUT/watch_resume.txt"

echo
echo "== step 7: watch from current head for future events only =="
set +e
(
  sleep 0.3
  "${ETCDCTL[@]}" put /demo/pod/d done
) &
timeout 2s "${ETCDCTL[@]}" watch --prefix /demo/pod/ >"$OUT/watch_future.raw" 2>&1
set -e
strip_noise < "$OUT/watch_future.raw" | tee "$OUT/watch_future.txt"

echo
echo "== summary =="
python3 - <<PY | tee "$OUT/summary.txt"
from pathlib import Path
out = Path("$OUT")
watch_from = (out / "watch_from_rev.txt").read_text().strip()
current = (out / "current_rev.txt").read_text().strip()
compact = (out / "compact_rev.txt").read_text().strip()
events = (out / "event_count.txt").read_text().strip()
compacted = (out / "watch_compacted.txt").read_text()
get_err = (out / "get_compacted.txt").read_text()
print(f"etcd_version=3.7.2")
print(f"watch_from_revision={watch_from}")
print(f"revision_after_initial_puts={current}")
print(f"compacted_revision={compact}")
print(events)
print("--- ErrCompacted (watch) ---")
for line in compacted.splitlines():
    if "compact" in line.lower() or "Error" in line or "canceled" in line.lower():
        print(line)
print("--- ErrCompacted (get) ---")
for line in get_err.splitlines():
    if "compact" in line.lower() or "Error" in line:
        print(line)
PY

echo
echo "Done. Artifacts in $OUT/"
