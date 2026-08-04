# eG Converged Application Demo (RUM + Java APM/BTM)

A lightweight, 3-JVM Java (Spring Boot) e-commerce checkout app for demoing
**eG Enterprise Real User Monitoring and Java APM** on minikube. Every stage of
the checkout storyline maps to a specific eG capability.

## Architecture

```
   Browser (Chrome / Windows / Singapore)
        │  loads checkout page  ──► Core Web Vitals (CLS > 0.25), Session Replay
        │  POST /api/placeOrder  (slow Ajax)
        ▼
 ┌───────────────┐   exit call    ┌────────────────────────────────────────────┐
 │  storefront   │ ─────────────► │  order-service  (Checkout business txn/BTM) │
 │  (JVM 1:8080) │                │  (JVM 2 : 8081)                             │
 └───────────────┘                │   1. PricingService.calculatePricingAndRisk │  slow method (custom pointcut)
                                   │   2. slow SELECT + INSERT ───► MySQL        │  SQL exit call + DB Visibility
                                   │   3. HTTP authorize()  ─────► payment-gw    │  3rd-party exit call
                                   │   4. publish ───► Artemis "order.notifications"
                                   └───────────────────────┬─────────────────────┘
                                                           ▼
                                              ┌────────────────────────────┐
                                              │  notification-worker        │  slow consumer →
                                              │  (JVM 3 : 8082)             │  queue backs up (pickup delay)
                                              └────────────────────────────┘
```

Three JVMs: **storefront**, **order-service**, **notification-worker**.
Supporting containers (not JVMs): **MySQL**, **ActiveMQ Artemis**, and a
**payment-gateway** mock (httpbin).

## Storyline → capability → where it lives

| Story element | eG capability | In this app |
|---|---|---|
| Chrome / Windows / Singapore segmentation | Browser RUM, Analyze, Geo | Real browser sessions against the checkout page |
| Checkout page performance | Browser RUM pages / virtual pages | `storefront` `index.html` (virtual-page marker included) |
| CLS + loading experience | Core Web Vitals | Late-injected promo banner + reco strip push the pay button down (CLS > 0.25) |
| What the customer saw / clicked | Session Replay | Shifting pay button + rage-click handling + "frozen" overlay |
| Slow /placeOrder request | Ajax monitoring | `POST /api/placeOrder` fetch in `index.html` |
| Ajax → server correlation | RUM–APM correlation | storefront `/api/placeOrder` → order-service `/placeOrder` |
| Checkout business transaction | APM / BTM | `order-service` `CheckoutController.placeOrder` |
| Slow application tier | Transaction flow map | storefront → order-service → MySQL / payment-gw / Artemis |
| Slow method | Call graph / code diagnostics | `PricingService.calculatePricingAndRisk` (→ `runFraudHeuristics`) |
| Downstream 3rd-party service | Exit calls / remote-service | `PaymentGatewayClient.authorize` → httpbin `/delay/1` |
| SQL query | SQL exit-call visibility | `OrderRepository.saveOrder` (slow SELECT with `SLEEP()`) |
| Message-queue pickup delay | Backed-up messages | `notification-worker` slow consumer on `order.notifications` |
| Detailed database diagnosis | Database Visibility | MySQL with slow query log enabled |

## Prerequisites
- minikube running (`minikube start`)
- JDK 17, Maven, kubectl, Docker

## Build & deploy

**Windows (PowerShell):**
```powershell
cd converged-demo
.\deploy.ps1
```
If script execution is blocked, allow it for this session first:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**macOS / Linux (bash):**
```bash
cd converged-demo
chmod +x deploy.sh load-test.sh
./deploy.sh
```

Open the store (Docker driver on Windows needs a tunnel, not the node IP):
```powershell
kubectl -n converged-demo port-forward svc/storefront 8080:8080   # or: app.bat url
# then browse to http://localhost:8080/
```

## Guided demo flow (page by page)

The app is a normal-looking store. Walk the shopper's journey; each page has one
natural performance problem you can then open in eG RUM. "I opened page A, here
is what happened, now let me show it in RUM/BTM."

1. **Home `/`** — the product catalog takes ~4.5s to appear (slow catalog API on
   the storefront tier). Talking point: **LCP > 4000ms**. The largest image (the
   hero) paints late. In RUM: poor LCP for this page; in APM: slow `/api/products`.

2. **Product `/product?id=h1`** — click a product. The image loads, then a moment
   later the **Customer reviews** (~2.5s) and **Frequently bought together**
   (~4.5s) blocks drop in and push the page down. Talking point: **CLS**. In RUM:
   layout-shift score and the shifting elements; in APM: slow `/api/reviews` and
   `/api/related`.

3. **Cart `/cart`** — change an item quantity with the +/− buttons. Each click is
   janky because pricing is recalculated on the main thread (~700ms). Talking
   point: **INP (poor)**. In RUM: the slow interaction and its INP value. Click a
   few times to build the sample.

4. **Checkout `/checkout`** — on load a "secure payment SDK" freezes the page for
   ~2.5s. Click **Pay** while it's still frozen. Talking point: **FID** (first
   input delay). In RUM: the first-input latency.

5. **Place order** — the **Pay** click fires the slow `/placeOrder` Ajax (> 4000ms).
   Talking point: **slow Ajax → RUM/APM correlation → Checkout business
   transaction**. Follow it in APM through the tiers: slow method
   (`PricingService.calculatePricingAndRisk`), SQL exit call, 3rd-party payment
   exit call, and the Artemis publish. Then land on the fast **Confirmation** page
   as a healthy baseline.

6. **Message-queue backlog** — generate load so the notification queue backs up:
   ```powershell
   .\load-test.ps1 40 4      # Windows  (start the tunnel first: app.bat url)
   ```
   ```bash
   ./load-test.sh 40 4       # macOS / Linux
   ```
   Watch the depth climb in the Artemis console:
   ```bash
   kubectl -n converged-demo port-forward svc/artemis 8161:8161
   # http://localhost:8161  (admin / admin) → Queues → order.notifications
   ```

### Page → metric → cause (cheat sheet)
| Page | Metric to show | Underlying cause |
|---|---|---|
| Home `/` | LCP > 4s | slow `/api/products` (catalog delay) |
| Product `/product` | CLS | late `/api/reviews` + `/api/related`, no reserved height |
| Cart `/cart` | INP (poor) | ~700ms main-thread block on quantity change |
| Checkout `/checkout` | FID | ~2.5s "payment SDK" block on load |
| Place order (Ajax) | slow Ajax → BTM | order-service slow method + SQL + exit call + MQ (>4s) |
| Confirmation `/confirmation` | healthy baseline | — |

All page delays are tunable without a rebuild via env vars on the storefront
(`CATALOG_PRODUCTS_DELAY_MS`, `CATALOG_REVIEWS_DELAY_MS`, `CATALOG_RELATED_DELAY_MS`).

## Generating continuous load automatically

Two generators, depending on what you want to fill:

**Real RUM sessions (browser) — recommended.** Drives a real headless browser
through every page (LCP, CLS, INP, FID, slow Ajax) and completes checkouts, so
eG Browser RUM, Session Replay and APM all get continuous data. It also
`ignoreHTTPSErrors`, so `egrum.js` loads even with the self-signed collector cert.
```powershell
app.bat url                 # start the tunnel first (keeps http://localhost:8080 open)
cd rum-load
$env:CONCURRENCY = 3        # optional: parallel virtual users
.\run.ps1                   # first run installs Playwright + Chromium; Ctrl+C to stop
```
Requires Node.js (`winget install OpenJS.NodeJS.LTS`). Options via env vars:
`CONCURRENCY`, `ITERATIONS` (0 = forever), `HEADED=1` to watch, `CHECKOUT_PCT`.

**Server-side only (APM/BTM/MQ, no RUM).** No Node needed; loops the URLs and the
checkout endpoint. Produces backend load but NO browser Core Web Vitals.
```powershell
app.bat url
.\traffic.ps1 3             # 3 workers; Ctrl+C to stop
```

## Tuning the faults live (no rebuild)
```bash
# Make the slow method slower
kubectl -n converged-demo set env deploy/order-service PRICING_DELAY_MS=3000
# Make the SQL slower
kubectl -n converged-demo set env deploy/order-service SQL_SLEEP_SECONDS=3
# Make the queue back up faster
kubectl -n converged-demo set env deploy/notification-worker CONSUMER_PROCESSING_MS=8000
```

## Adding the eG agents (do this yourself)
- **Browser RUM:** paste the eG RUM `<script>` tag into the `<head>` of
  `storefront/src/main/resources/static/index.html` (placeholder is marked).
  Optionally call `trackVirtualPage('/checkout/payment')` at the marker.
- **Java APM:** in each `Dockerfile`, COPY the eG agent jar and set
  `JAVA_OPTS="-javaagent:/opt/eg-apm-agent/eg-apm.jar"`. Add a **custom pointcut**
  for `com.eginnovations.demo.order.PricingService.calculatePricingAndRisk`
  so the slow method appears by name in the call graph.

## Ports
| Service | Port | Notes |
|---|---|---|
| storefront | 8080 (NodePort 30080) | checkout page + Ajax proxy |
| order-service | 8081 | Checkout business transaction |
| notification-worker | 8082 | slow Artemis consumer |
| MySQL | 3306 | shopdb / shop / shoppass |
| Artemis | 61616 core, 8161 console | admin / admin |
| payment-gateway | 8080 | httpbin `/delay/1` |
