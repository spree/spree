import { randomUUID } from 'node:crypto'
import { resolve } from 'node:path'
import { expect, test } from '@playwright/test'
import { API_GEM_DIR, runRailsBootstrap } from './rails'

const apiUrl = `http://localhost:${process.env.E2E_RAILS_PORT || '3010'}`
const railsEnv = {
  ...process.env,
  RAILS_ENV: 'test',
  DATABASE_URL: `sqlite3:${resolve(API_GEM_DIR, 'spec/dummy/db/spree_test_e2e.sqlite3')}`,
}

// This Store API flow has no dashboard cart screen. Assert the customer-facing
// response from the real server; no browser or mocked pricing is involved.
test('reprices all cart lines when the buyer chooses, switches or clears a company', async ({
  request,
}) => {
  const code = `company-cart-${Date.now()}`
  const email = `${code}@example.com`
  const password = randomUUID()
  try {
    const fixture = JSON.parse(
      runRailsBootstrap(
        `
      Spree::Events.disable do
        store = Spree::Store.create!(name: '${code}', code: '${code}', url: '${code}.invalid',
          mail_from_address: 'fixture@example.com', default_currency: 'USD', default_locale: 'en',
          default_country_code: 'US', default: false, preferred_send_consumer_transactional_emails: false)
        Spree::Current.store = store
        Spree::Current.channel = store.default_channel
        customer = Spree.customer_class.create!(email: '${email}', password: '${password}', password_confirmation: '${password}')
        key = Spree::ApiKey.create!(store: store, name: '${code}', key_type: 'publishable')
        profile = Spree::DeliveryProfile.default_for(store) || Spree::DeliveryProfiles::Shipping.create!(store: store, name: '${code}', default: true)
        location = Spree::StockLocation.create!(store: store, name: '${code}', active: true, country_code: 'US', propagate_all_variants: false)
        store.default_channel.stock_locations = [location]
        variants = 2.times.map do |n|
          product = Spree::Product.create!(store: store, name: '${code} '+n.to_s, status: 'active', delivery_profile: profile)
          product.product_publications.create!(channel: store.default_channel, published_at: 1.day.ago)
          product.default_variant.tap do |variant|
            variant.set_price('USD', '10.00')
            location.stock_level_or_create(variant).set_count_on_hand(10)
          end
        end
        companies = [7, 13].map do |amount|
          company = Spree::Company.create!(store: store, name: '${code} '+amount.to_s)
          Spree::CompanyMembership.create!(company: company, customer: customer)
          catalog = Spree::Catalog.create!(store: store, name: company.name, active: true)
          list = Spree::PriceList.create!(store: store, catalog: catalog, name: company.name, status: 'active')
          Spree::CatalogAssignment.create!(catalog: catalog, assignable: company)
          variants.each { |variant| Spree::Price.create!(variant: variant, price_list: list, currency: 'USD', amount: amount) }
          company
        end
        puts JSON.generate(key: key.token, variant_ids: variants.map(&:prefixed_id), company_ids: companies.map(&:prefixed_id))
      end
    `,
        railsEnv,
      ),
    ) as { key: string; variant_ids: string[]; company_ids: string[] }
    const headers: Record<string, string> = { 'X-Spree-Api-Key': fixture.key }
    const login = await request.post(`${apiUrl}/api/v3/store/auth/login`, {
      headers,
      data: { email, password },
    })
    expect(login.status()).toBe(200)
    headers.Authorization = `Bearer ${(await login.json()).token}`
    const created = await request.post(`${apiUrl}/api/v3/store/carts`, { headers, data: {} })
    expect(created.status()).toBe(201)
    const opened = await created.json()
    headers['X-Spree-Token'] = opened.token
    const cartUrl = `${apiUrl}/api/v3/store/carts/${opened.id}`
    const add = await request.patch(cartUrl, {
      headers,
      data: { items: fixture.variant_ids.map((variant_id) => ({ variant_id, quantity: 1 })) },
    })
    expect(add.status()).toBe(200)
    expect((await add.json()).items.map((item: { price: string }) => item.price)).toEqual([
      '10.00',
      '10.00',
    ])
    for (const [company_id, expected] of [
      [fixture.company_ids[0], '7.00'],
      [fixture.company_ids[1], '13.00'],
      [null, '10.00'],
    ] as const) {
      const updated = await request.patch(cartUrl, { headers, data: { company_id } })
      expect(updated.status()).toBe(200)
      const cart = await updated.json()
      expect(cart.company_id).toBe(company_id)
      expect(cart.items.map((item: { price: string }) => item.price)).toEqual([expected, expected])
      const fetched = await request.get(cartUrl, { headers })
      expect(fetched.status()).toBe(200)
      expect((await fetched.json()).items.map((item: { price: string }) => item.price)).toEqual([
        expected,
        expected,
      ])
    }
  } finally {
    const cleaned = JSON.parse(
      runRailsBootstrap(
        `
      store = Spree::Store.find_by(code: '${code}')
      if store
        abort 'Foreign fixture forbidden' unless store.name == '${code}' && !store.default?
        Spree::Events.disable do
          store.carts.each do |cart|
            abort 'Placed cart forbidden' unless cart.completed_at.nil? && cart.payments.empty? && cart.customer&.email == '${email}'
            cart.destroy!
          end
          abort 'Placed order forbidden' if store.orders.exists?
          Spree::CompanyMembership.where(company_id: store.companies.select(:id)).destroy_all
          Spree::Price.where(price_list_id: store.price_lists.select(:id)).destroy_all
          store.catalogs.each(&:destroy!)
          store.products.each(&:destroy!)
          Spree::ApiKey.where(store: store).destroy_all
          customer = Spree.customer_class.find_by(email: '${email}')
          Spree::RefreshToken.revoke_all_for(customer) if customer
          puts JSON.generate(keys: store.api_keys.count, carts: store.carts.count, products: store.products.count, catalogs: store.catalogs.count)
        end
      else
        puts '{}'
      end
    `,
        railsEnv,
      ),
    ) as Record<string, number>
    expect(Object.values(cleaned).every((value) => value === 0)).toBe(true)
  }
})
