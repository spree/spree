#!/usr/bin/env bash
# Reference solution: an order.placed subscriber, generated with the CLI (which
# registers it), then filled in.
set -euo pipefail
npx --no-install spree eject
npx --no-install spree generate subscriber OrderSync order.placed
cp -R "$REFERENCE_DIR/overlay/." .
grep -n 'OrderSyncSubscriber' server/config/initializers/spree.rb
npx --no-install spree restart
npx --no-install spree exec bin/rails db:test:prepare
npx --no-install spree test spec/subscribers/order_sync_subscriber_spec.rb
