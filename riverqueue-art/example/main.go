package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
)

type SendReceiptArgs struct {
	OrderID string `json:"order_id"`
	Email   string `json:"email"`
}

func (SendReceiptArgs) Kind() string { return "send_receipt" }

type SendReceiptWorker struct {
	river.WorkerDefaults[SendReceiptArgs]
}

func (w *SendReceiptWorker) Work(ctx context.Context, job *river.Job[SendReceiptArgs]) error {
	slog.Info("sending receipt", "order", job.Args.OrderID, "to", job.Args.Email, "attempt", job.Attempt)
	return nil // returning a non-nil error triggers River's retry/backoff
}

func main() {
	ctx := context.Background()

	pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	must(err)
	defer pool.Close()

	workers := river.NewWorkers()
	river.AddWorker(workers, &SendReceiptWorker{})

	client, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Queues:  map[string]river.QueueConfig{river.QueueDefault: {MaxWorkers: 10}},
		Workers: workers,
	})
	must(err)

	must(client.Start(ctx))
	defer client.Stop(ctx)

	tx, err := pool.Begin(ctx)
	must(err)
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `INSERT INTO orders (id, total_cents) VALUES ($1, $2)`, "ord_42", 4999)
	must(err)

	// the enqueue is just another INSERT in the same transaction
	_, err = client.InsertTx(ctx, tx, SendReceiptArgs{OrderID: "ord_42", Email: "a@b.com"}, nil)
	must(err)

	must(tx.Commit(ctx))

	time.Sleep(2 * time.Second) // let the in-process worker drain before we exit
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
