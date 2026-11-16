#!/usr/bin/env bash
# Reference solution: a validate hook on both cart workflows.
set -euo pipefail
cat >> server/config/initializers/spree.rb <<'RUBY'

# At most 10 units of a variant per cart line, however the quantity is reached.
Spree.hooks.register('carts.add_item.validate', 'CartLimits::MaxQuantityPerLineOnAdd')
Spree.hooks.register('carts.upsert_items.validate', 'CartLimits::MaxQuantityPerLine')
RUBY
npx --no-install spree eject
npx --no-install spree exec bin/rails db:test:prepare
npx --no-install spree test spec/requests/cart_quantity_limit_spec.rb
