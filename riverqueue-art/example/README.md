# River queue — minimal example

Single-file demo that enqueues a job *inside the same transaction* as a business write.

## Run it

```bash
export DATABASE_URL="postgres://river:river@localhost:5432/riverdemo?sslmode=disable"

docker compose up -d
go run ./cmd/migrate
go run .
```

Expected output:

```
sending receipt order=ord_42 to=a@b.com attempt=1
```

## What to look at

- `main.go` — the whole story in ~60 lines. The line that matters is `client.InsertTx(ctx, tx, ...)` — the job row is inserted in the same `tx` as the `orders` INSERT.
- `cmd/migrate/main.go` — creates the `orders` table and runs River's own migrations.

## Try the failure case

Comment out `tx.Commit(ctx)` and re-run. The `orders` row never appears — and neither does the job. That is the property River is selling.
