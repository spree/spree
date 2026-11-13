#!/usr/bin/env bash
# Reference solution: the definition through the Admin API (with a key minted
# by the CLI), and a script that filters on its cf_ key.
set -euo pipefail
port=$(grep -E '^SPREE_PORT=' .env | cut -d= -f2)
key=$(npx --no-install spree api-key create --name products-by-origin --type secret --scopes write_all \
  | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'sk_[A-Za-z0-9_-]{8,}' | head -1)
curl -fsS -X POST "http://localhost:${port}/api/v3/admin/custom_field_definitions" \
  -H "x-spree-api-key: ${key}" -H 'content-type: application/json' \
  -d '{"resource_type":"product","namespace":"specs","key":"origin","label":"Origin","field_type":"short_text","storefront_visible":true,"searchable":true,"sortable":true}'
echo
# Try it: one product from Portugal, one from Spain.
SPREE_API_URL="http://localhost:${port}" SPREE_SECRET_KEY="$key" node scripts/products-by-origin.mjs Portugal
