import { resolve } from 'node:path'
import { expect, test } from '@playwright/test'
import { login, searchList } from './helpers'
import { API_GEM_DIR, runRailsBootstrap } from './rails'

test.use({ trace: 'off' })

const railsEnv = {
  ...process.env,
  RAILS_ENV: 'test',
  DATABASE_URL: `sqlite3:${resolve(API_GEM_DIR, 'spec/dummy/db/spree_test_e2e.sqlite3')}`,
}

// Complete and resume through Store HTTP, then inspect seller orders in the
// dashboard and verify exact reservation and allocation counts.
for (const [sellerCount, retained] of [
  [1, false],
  [2, false],
  [1, true],
  [2, true],
] as const) {
  test(`a cart ${retained ? 'resumes' : 'completes'} its own reserved stock across ${sellerCount} seller partitions`, async ({
    page,
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
        store = create(:store, name: 'ZZ Reserved checkout ${Date.now()}', preferred_stock_reservations_enabled: true)
        admin = Spree.admin_user_class.first!
        store.add_user(admin, Spree::Role.default_admin_role(store))
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
        draft = nil
        if ${retained}
          interrupted = Class.new(Spree::Carts::Complete) do
            workflow_key 'carts.complete'
            private
            def finalize_completion
              failure(cart, code: 'completion_failed')
            end
          end
          raise 'Expected a retained paid draft' unless interrupted.call(cart: cart).failure?
          draft = Spree::Order.find_by!(cart_id: cart.id)
          raise 'Draft lost its holds' unless draft.stock_reservations.count == lines.length
          cart.reload.update_column(:completing_at, 6.minutes.ago)
        end
        puts({store: store.prefixed_id, cart: cart.prefixed_id, token: cart.token, key: key.plaintext_token, quantities: lines.map(&:quantity),
              levels: levels.map(&:id), other_hold: hold.id, other_cart: other.id, draft: draft&.prefixed_id}.to_json)
      `,
        railsEnv,
      ),
    )
    const rails = `http://localhost:${process.env.E2E_RAILS_PORT || '3010'}`
    const headers = { 'X-Spree-API-Key': fixture.key, 'X-Spree-Token': fixture.token }
    if (retained) {
      const changed = await request.patch(`${rails}/api/v3/store/carts/${fixture.cart}`, {
        headers,
        data: {
          shipping_address: { city: 'Changed after payment' },
          customer_note: 'Must stay fenced',
        },
      })
      expect(changed.status()).toBe(409)
      expect((await changed.json()).error.code).toBe('completion_in_progress')
    }
    const completed = await request.post(`${rails}/api/v3/store/carts/${fixture.cart}/complete`, {
      headers,
      data: {},
    })
    expect(completed.status()).toBe(200)
    const order = await completed.json()
    expect(order.id).toMatch(sellerCount === 1 ? /^or_/ : /^ogrp_/)
    if (retained && sellerCount === 1) expect(order.id).toBe(fixture.draft)
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

    await login(page)
    await page.goto(`/${fixture.store}/orders`)
    await expect(page.getByRole('heading', { name: /^orders$/i })).toBeVisible()
    for (const child of sellerCount === 1 ? [order] : order.orders) {
      await searchList(page, /search by number/i, child.number)
      await expect(page.getByRole('row').filter({ hasText: child.number })).toBeVisible()
    }
  })
}
