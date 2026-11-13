#!/usr/bin/env bash
# Reference solution: a column on carts and orders, written through the cart
# update service, shown by the cart and order serializers, copied at checkout.
set -euo pipefail
cat >> server/config/initializers/spree.rb <<'RUBY'

# Gift message: writable on the Store API cart, shown on carts and orders, and
# copied onto the order when the cart is placed.
# In to_prepare: Spree's models cannot be loaded while initializers run. The
# Store API's cart endpoints read Spree::Order's list, not Spree::Cart's.
Rails.application.config.to_prepare do
  Spree::Cart.additional_permitted_attributes += [:gift_message]
  Spree::Order.additional_permitted_attributes += [:gift_message]
end
Spree.dependencies do |dependencies|
  dependencies.carts_update_service = 'GiftMessages::CartUpdate'
end
Rails.application.config.after_initialize do
  Spree.api.extension_fields.attribute(:cart_serializer, method: :gift_message)
  Spree.api.extension_fields.attribute(:order_serializer, method: :gift_message)
  Spree.cart_copiers << GiftMessages::CopyToOrder
end
RUBY
npx --no-install spree eject
npx --no-install spree migrate
npx --no-install spree restart
npx --no-install spree exec bin/rails db:test:prepare
npx --no-install spree test spec/requests/gift_message_spec.rb
