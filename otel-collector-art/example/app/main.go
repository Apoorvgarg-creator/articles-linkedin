// A tiny "checkout-api" that emits the kind of spans real services emit:
// lots of health checks, a few real requests, and attributes that should
// never leave your network. It knows nothing about filtering or scrubbing.
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func main() {
	ctx := context.Background()

	exp, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint("localhost:4318"),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		log.Fatal(err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(resource.NewSchemaless(
			semconv.ServiceName("checkout-api"),
		)),
	)
	tracer := tp.Tracer("demo")

	// 20 health checks: the load balancer pings every few seconds.
	for i := 0; i < 20; i++ {
		_, span := tracer.Start(ctx, "GET /healthz")
		span.SetAttributes(attribute.String("http.route", "/healthz"))
		span.End()
	}

	// 5 real checkouts, carrying data you do not want in a vendor's database.
	for i := 1; i <= 5; i++ {
		_, span := tracer.Start(ctx, "POST /checkout")
		span.SetAttributes(
			attribute.String("http.route", "/checkout"),
			attribute.String("user.email", fmt.Sprintf("user%d@example.com", i)),
			attribute.String("http.request.header.authorization", "Bearer sk_live_not_a_real_token"),
			attribute.Int("order.total_cents", 4999*i),
		)
		time.Sleep(5 * time.Millisecond)
		span.End()
	}

	// Shutdown flushes the batcher, so every span is sent before we exit.
	if err := tp.Shutdown(ctx); err != nil {
		log.Fatal(err)
	}
	fmt.Println("app: sent 25 spans (20 x /healthz, 5 x /checkout) to localhost:4318")
}
