# Diagrams (Excalidraw style: hand-drawn boxes, short labels, ASCII arrows)

Palette suggestion: receiver = blue, processors = yellow, exporters = green, connector = purple, dropped/leaked data = red. White background, 1600x900, readable on mobile.

## 1. diagrams/fanout-graph.png

Purpose: show that one receiver feeds two independent pipelines, and who gets a clone.

Layout, left to right:

- Far left: small rounded box **"checkout-api (Go SDK)"** -> arrow labeled **"OTLP/HTTP :4318"** -> blue box **"receiver: otlp"**.
- From the receiver, one arrow into a circle labeled **"fan-out"**. Under the circle, tiny caption: *"clones only for pipelines that mutate"*.
- From the fan-out, two arrows:
  - Top arrow labeled **"clone (mutates)"** into a dashed container titled **"traces/vendor"** holding three yellow boxes in a row: **"memory_limiter"** -> **"filter: drop /healthz"** -> **"attributes: hash email, drop auth"** -> green box **"file/vendor (your paid backend)"**.
  - Bottom arrow labeled **"original (read-only)"** into a dashed container titled **"traces/counts"** holding yellow **"memory_limiter"** -> purple diamond **"count connector"**.
- From the purple connector, an arrow downward/right into a dashed container titled **"metrics/counts"** -> green box **"file/counts"**. Label the arrow **"traces -> metrics"**.
- Footer note in small handwriting font: *"Same processor name in 2 pipelines = 2 separate instances"*.

## 2. diagrams/span-journey.png

Purpose: make the result concrete by following two real spans from the demo.

Layout: two horizontal swim lanes, each starting at the left with a span card.

- Lane 1 card: **"GET /healthz"** (gray card). Arrow -> fan-out, then splits:
  - Upper branch into **traces/vendor**: arrow hits yellow box **"filter"** and ends in a red X labeled **"dropped (not billed)"**.
  - Lower branch into **traces/counts**: -> purple **"count"** -> green box **"app.span.count{route=/healthz} = 20"**.
- Lane 2 card: **"POST /checkout"** with three attribute lines on the card: `user.email = user1@example.com`, `authorization = Bearer sk_live_...`, `order.total_cents = 4999`. Arrow -> fan-out, then splits:
  - Upper branch into **traces/vendor**: passes **"filter"** (green check), then **"attributes"**, ends at green box **"vendor"** showing the card after: `user.email = b36a8370...fe210`, `authorization` struck through, `order.total_cents = 4999`.
  - Lower branch: -> **"count"** -> **"app.span.count{route=/checkout} = 5"**.
- Bottom banner: **"Vendor: 5 spans, no PII. Metrics: all 25 counted."**
