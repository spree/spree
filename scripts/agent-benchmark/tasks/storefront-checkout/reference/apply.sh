#!/usr/bin/env bash
# Reference solution: a Next.js App Router shop on @spree/sdk (files/), plus a
# payment method that needs no card. The seeded store already has shipping
# rates for the US.
set -euo pipefail
port=$(grep -E '^SPREE_PORT=' .env | cut -d= -f2)
api="http://localhost:${port}/api/v3/admin"
secret=$(npx --no-install spree api-key create --name shop-setup --type secret --scopes write_all \
  | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'sk_[A-Za-z0-9_-]{8,}' | head -1)
publishable=$(npx --no-install spree api-key create --name shop --type publishable \
  | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'pk_[A-Za-z0-9_-]{8,}' | head -1)

if ! curl -fsS "${api}/payment_methods" -H "x-spree-api-key: ${secret}" | grep -q '"type":"check"'; then
  curl -fsS -X POST "${api}/payment_methods" -H "x-spree-api-key: ${secret}" -H 'content-type: application/json' \
    -d '{"type":"check","name":"Pay by check","active":true,"storefront_visible":true}'
  echo
fi

cd apps/shop
npm install --no-audit --no-fund
SPREE_API_URL="http://localhost:${port}" SPREE_PUBLISHABLE_KEY="$publishable" npm run build
