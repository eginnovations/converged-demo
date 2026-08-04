#!/usr/bin/env bash
# Drive checkout traffic so the notification queue backs up and RUM/APM light up.
# Usage: ./load-test.sh [count] [concurrency]
set -euo pipefail

COUNT="${1:-40}"
CONC="${2:-4}"
URL="http://$(minikube ip):30080/api/placeOrder"

echo "Firing $COUNT orders ($CONC at a time) at $URL"
seq "$COUNT" | xargs -P "$CONC" -I{} curl -s -o /dev/null -w "order {} -> %{http_code} in %{time_total}s\n" \
  -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d '{"items":["SKU-HEADPH-01","SKU-CHRG-USBC"],"amount":159.00,"currency":"USD"}'

echo "Done. Check the Artemis console (order.notifications) for the growing backlog."
