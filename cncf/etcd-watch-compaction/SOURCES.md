# Sources (primary, checked 2026-10-14)

## CNCF status
- etcd on CNCF (incubating Dec 11, 2018; graduated Nov 24, 2020): https://www.cncf.io/projects/etcd/
- Graduation announcement: https://www.cncf.io/announcements/2020/11/24/cloud-native-computing-foundation-announces-etcd-graduation/

## Revisions, watch, compaction
- etcd API overview (revisions, MVCC, Watch Start_Revision, Compact_Revision): https://etcd.io/docs/v3.5/learning/api/
- Maintenance / history compaction (etcdctl compact, get --rev error text, auto-compaction modes): https://etcd.io/docs/v3.6/op-guide/maintenance/
- Server/client error definitions (ErrGRPCCompacted / ErrCompacted, message string, OutOfRange): https://github.com/etcd-io/etcd/blob/main/api/v3rpc/rpctypes/error.go
- clientv3 Watcher docs and WatchResponse.Err() (CompactRevision -> ErrCompacted): https://github.com/etcd-io/etcd/blob/main/client/v3/watch.go
- Maintainers on compaction: do not auto-resume compacted watches; reopen from a non-compacted revision: https://github.com/etcd-io/etcd/issues/8668

## Release used in the demo
- etcd v3.7.2 (2026-09-22): https://github.com/etcd-io/etcd/releases/tag/v3.7.2
- Patch notes (v3.7.2 / v3.6.15 / v3.5.34): https://etcd.io/blog/2026/sep-21-patch-release/

## Measured locally (not from docs)
- Single-node etcd v3.7.2 linux/amd64 (Git SHA 68c065e, Go 1.26.8).
- watch --rev=2 --prefix /demo/pod/ after three puts: events_seen=3.
- etcdctl compact 6 -> "compacted revision 6".
- watch --rev=2 after compact: "watch was canceled (etcdserver: mvcc: required revision has been compacted)" / "Error: watch is canceled by the server".
- get --rev=2: "Error: etcdserver: mvcc: required revision has been compacted".
- Artifacts: example/out/summary.txt, watch_ok.txt, watch_compacted.txt, get_compacted.txt, relist.txt.
