package main

import (
	"context"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river/rivermigrate"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
)

func main() {
	ctx := context.Background()

	pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS orders (
			id          TEXT PRIMARY KEY,
			total_cents INT  NOT NULL
		)
	`); err != nil {
		log.Fatal(err)
	}

	migrator, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		log.Fatal(err)
	}
	if _, err := migrator.Migrate(ctx, rivermigrate.DirectionUp, nil); err != nil {
		log.Fatal(err)
	}
	log.Println("migrations applied")
}
