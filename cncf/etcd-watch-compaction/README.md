# etcd watch + compaction: why resuming from an old revision fails

Watch from revision 2, compact at 6, and etcd cancels the watch with
"required revision has been compacted" (ErrCompacted in Go clients).
The fix is to re-list current keys, then watch from a revision that still exists.

## Key results (etcd v3.7.2, single node, linux/amd64)

| Step | Result |
|---|---|
| put a, put b, update a | revisions 2, 3, 4 |
| `watch --rev=2 --prefix /demo/pod/` | events_seen=3 |
| put c, update b, `compact 6` | `compacted revision 6` |
| `watch --rev=2` again | `watch was canceled (etcdserver: mvcc: required revision has been compacted)` |
| `get --rev=2 /demo/pod/a` | `Error: etcdserver: mvcc: required revision has been compacted` |
| `get --prefix /demo/pod/` | a=ready, b=ready, c=starting |
| `watch --rev=6` | `PUT /demo/pod/b ready` |

Full captured output: [example/out/](example/out/).

## Run it

Needs Linux amd64, bash, curl and python3. No Docker.

```bash
cd example
./run.sh
```

The script downloads etcd v3.7.2 once into `example/bin/`, starts one node on
127.0.0.1:2379 and 2380, runs every step and writes output to `example/out/`.
Set `ETCD_VER`, `CLIENT_PORT` or `PEER_PORT` to override.

## Gotchas

- Retrying the same start revision fails every time. The history is gone.
- In clientv3, `WatchResponse.Err()` returns `ErrCompacted` when `CompactRevision != 0`, and the watch channel closes.
- Changes between your last revision and the compaction point are not recoverable from etcd. Rebuild from a list.
- Auto-compaction (periodic, or revision mode keeping the last N revisions, checked every 5 minutes) moves the floor without you running `compact`.
- Kubernetes client-go informers talk to the API server, not etcd. The reflector re-lists when its resume point is too old.

## Files

- `article.md`: the newsletter article
- `article-images/`: images used in the article
- `carousel.pdf`: the slide version
- `SOURCES.md`: primary sources
- `diagrams/`: SVG + PNG of the revision timeline, compaction wall, controller path, and demo numbers
- `example/`: the runnable demo
