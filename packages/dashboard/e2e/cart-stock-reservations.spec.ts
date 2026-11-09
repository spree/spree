import { resolve } from 'node:path'
import { expect, test } from '@playwright/test'
import { API_GEM_DIR, runRailsBootstrap } from './rails'

test.use({ trace: 'off' })

const railsEnv = {
  ...process.env,
  RAILS_ENV: 'test',
  DATABASE_URL: `sqlite3:${resolve(API_GEM_DIR, 'spec/dummy/db/spree_test_e2e.sqlite3')}`,
}

// Store checkout has no dashboard surface. Exercise its public HTTP contract
// against the suite's isolated Rails database, without a browser session.
for (const sellerCount of [1, 2]) {
  test(`a cart completes its own reserved stock across ${sellerCount} seller partitions`, async ({
    request,
  }) => {
    test.setTimeout(120_000)
    const fixture = JSON.parse(
      runRailsBootstrap(
        `
        require 'factory_bot'
        require 'spree/testing_support/factories'
        Spree::Events.disable!
        include FactoryBot::Syntax::Methods
        store = create(:store, name: 'Reserved checkout ${Date.now()}', preferred_stock_reservations_enabled: true)
        Spree::Current.store = store
        location = create(:stock_location, store: store)
        create(:delivery_method, store: store)
        method = create(:check_payment_method, store: store)
        cart = create(:cart_ready_for_delivery, store: store, line_items_count: 0)
        lines = Array.new(${sellerCount}) do |index|
          product = create(:product, store: store, sku: "RESERVED-CHECKOUT-${Date.now()}-#{index}")
          if ${sellerCount} > 1
            product.default_variant.update!(seller: create(:seller, :approved, store: store))
          end
          create(:line_item, cart: cart, order: nil, variant: product.default_variant)
        end
        line = lines.first
        cart.rebuild_fulfillments!
        cart.set_fulfillments_cost
        cart.recalculate_totals!
        create(:payment, cart: cart, order: nil, payment_method: method, source: nil, amount: cart.reload.total)
        levels = lines.map do |item|
          level = item.variant.stock_levels.find_by!(stock_location: location)
          item.variant.stock_levels.each do |stock|
            stock.update!(backorderable: false)
            stock.set_count_on_hand(stock == level ? item.quantity + (item == line ? 1 : 0) : 0)
          end
          create(:stock_reservation, cart: cart, order: nil, line_item: item, stock_level: level, quantity: item.quantity)
          level
        end
        other = create(:cart, store: store)
        other_line = create(:line_item, cart: other, order: nil, variant: line.variant)
        hold = create(:stock_reservation, cart: other, order: nil, line_item: other_line, stock_level: levels.first, quantity: 1)
        key = create(:api_key, :publishable, store: store)
        raise 'Cart has no selected delivery' unless cart.fulfillments.all?(&:selected_delivery_rate)
        raise 'Cart does not cover its own stock' unless lines.all?(&:sufficient_stock?)
        puts({cart: cart.prefixed_id, token: cart.token, key: key.plaintext_token, quantities: lines.map(&:quantity),
              levels: levels.map(&:id), other_hold: hold.id, other_cart: other.id}.to_json)
      `,
        railsEnv,
      ),
    )
    const rails = `http://localhost:${process.env.E2E_RAILS_PORT || '3010'}`
    const headers = { 'X-Spree-API-Key': fixture.key, 'X-Spree-Token': fixture.token }
    const completed = await request.post(`${rails}/api/v3/store/carts/${fixture.cart}/complete`, {
      headers,
      data: {},
    })
    expect(completed.status()).toBe(200)
    const order = await completed.json()
    expect(order.id).toMatch(sellerCount === 1 ? /^or_/ : /^ogrp_/)
    if (sellerCount === 2) expect(order.orders).toHaveLength(2)
    expect(order.completed_at).toBeTruthy()
    const repeated = await request.post(`${rails}/api/v3/store/carts/${fixture.cart}/complete`, {
      headers,
      data: {},
    })
    expect(repeated.status()).toBe(200)
    expect((await repeated.json()).id).toBe(order.id)

    const stock = JSON.parse(
      runRailsBootstrap(
        `
        levels = Spree::StockLevel.where(id: [${fixture.levels.join(',')}]).order(:id)
        counts = levels.map { |level| {allocated: level.allocated_count, reserved: level.reserved_count} }

        hold = Spree::StockReservation.find(${fixture.other_hold})
        puts({levels: counts, cart: hold.cart_id, order: hold.order_id}.to_json)
      `,
        railsEnv,
      ),
    )
    expect(stock).toEqual({
      levels: fixture.quantities.map((quantity: number, index: number) => ({
        allocated: quantity,
        reserved: index === 0 ? 1 : 0,
      })),
      cart: fixture.other_cart,
      order: null,
    })
  })
}
