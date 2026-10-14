# Your etcd watch died at revision 2. Compaction took the history.

Your controller loses its connection for a moment. It reconnects and asks etcd to replay everything since revision 2, the last one it saw. The watch closes at once with "required revision has been compacted". Nothing is broken. etcd deleted that history on purpose, and it refuses to let you pretend you caught up. The fix is not a retry. Re-list the keys you care about, then watch from a revision etcd still has.

I ran the whole thing on a single etcd v3.7.2 node so you can see each step with real output.

![Every write gets a number](article-images/img-02.png)

## Every write gets a number

etcd is the key-value store that Kubernetes keeps its state in. It keeps one counter for the whole cluster, called the revision. Every put or delete moves it up by one. A fresh store starts at revision 1.

In the demo I write three values under `/demo/pod/`:

```
put /demo/pod/a running   -> revision 2
put /demo/pod/b pending   -> revision 3
put /demo/pod/a ready     -> revision 4
```

etcd keeps the old values too. Under the hood this is called MVCC (multi-version concurrency control): you can read the store as it looked at any past revision.

## A watch can start in the past

That history is what makes a controller reliable. If it misses a few changes, it asks to watch from the last revision it saw, and etcd replays everything since then.

![A watch can start in the past](article-images/img-03.png)

```
$ etcdctl watch --rev=2 --prefix /demo/pod/
PUT /demo/pod/a running
PUT /demo/pod/b pending
PUT /demo/pod/a ready
events_seen=3
```

(trimmed: etcdctl prints key and value on separate lines)

Three changes, three events. Nothing was missed.

## Compaction throws old history away

Keeping every old value forever would fill the disk. So etcd compacts: it drops old versions of keys before a chosen revision. In the demo I make two more writes (`c=starting` at 5, `b=ready` at 6) and then compact:

```
$ etcdctl compact 6
compacted revision 6
```

![Compaction throws old history away](article-images/img-04.png)

In production you rarely run this by hand. Auto-compaction does it for you, either on a time window or by keeping the last N revisions.

## Wrong: resume from revision 2 again

Now the controller reconnects and does the obvious thing. This is the wrong way:

```
$ etcdctl watch --rev=2 --prefix /demo/pod/
watch was canceled (etcdserver: mvcc: required revision has been compacted)
Error: watch is canceled by the server
```

A plain read at that revision fails too:

```
$ etcdctl get --rev=2 /demo/pod/a
Error: etcdserver: mvcc: required revision has been compacted
```

![Wrong: resume from 2 again](article-images/img-05.png)

In Go, clientv3 reports this as `ErrCompacted`, and the watch response carries a non-zero `CompactRevision`. Retrying the same revision gives the same answer every time, because revision 2 is never coming back. Treat it as a gap in history, not a network blip.

## Right: re-list, then watch

The fix has two steps. First read what exists now. Then watch from a revision that is still there.

```
$ etcdctl get --prefix /demo/pod/
/demo/pod/a ready
/demo/pod/b ready
/demo/pod/c starting

$ etcdctl watch --rev=6 --prefix /demo/pod/
PUT /demo/pod/b ready
```

(trimmed, same format as above)

![Right: re-list, then watch](article-images/img-07.png)

The list is now your source of truth. Your cache rebuilds from it, and the watch keeps it fresh from revision 6 on.

## The gap is not replayed

Here is the catch. Whatever changed between your last revision and the compaction point is gone from etcd. In this demo that is `c=starting` landing at 5, which the controller only learns about from the list. If a key was created and deleted inside that window, you will never see it at all.

![The gap is not replayed](article-images/img-08.png)

## When to skip it

If you watch Kubernetes objects through client-go informers, you are not talking to etcd directly. The API server and the reflector cover this case: when the resume point is too old, the reflector re-lists. You do not need your own resume logic. Still learn the error message. When it shows up in your logs, the answer is a full re-list, not a sleep and retry.

Write your own handling when you build a custom controller or cache directly on etcd. Make `ErrCompacted` a planned path in your code, and keep your resume point inside your auto-compaction window.

## Try it

The script downloads etcd v3.7.2 once, starts one local node with no Docker, and prints every number in this post:

https://github.com/Apoorvgarg-creator/articles-linkedin/tree/main/cncf/etcd-watch-compaction

Run `./example/run.sh`. After the first download it finishes in a few seconds.

How does your controller handle ErrCompacted today?
