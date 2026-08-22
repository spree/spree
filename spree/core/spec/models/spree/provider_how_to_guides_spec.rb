require 'spec_helper'
# Exercises the exact shapes the v6 how-to guides document —
# docs/v6/developer/how-to/custom-pricing-provider.mdx and
# custom-inventory-provider.mdx — so the guides cannot drift from the
# contract without this failing. Keep the code here in step with the guides.
RSpec.describe 'Provider how-to guides' do
  let(:store) { @default_store }
  let(:variant) { create(:variant, price: 20) }

  it 'pricing guide: handles? via the cart company, price_for, and the Spree::Price contract' do
    company = create(:company, store: store)
    company.set_external_id('acme_erp', 'ACCT-9')
    location = create(:company_location, company: company)
    cart = create(:cart, store: store, company_location: location)

    provider = Class.new(Spree::PricingProvider::Base) do
      def self.key = 'acme_erp'
      def cache_ttl = 5.minutes
      def handles?(context) = context.order&.company&.external_id_for('acme_erp').present?
      def price_for(context)
        Spree::Price.new(variant: context.variant, currency: context.currency, amount: 7.5)
      end
    end

    checkout = Spree::Pricing::Context.from_order(variant, cart, quantity: 10)
    catalog  = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store)

    expect(provider.new.handles?(checkout)).to be(true)
    expect(provider.new.handles?(catalog)).to be(false)
    expect(provider.new.price_for(checkout).amount).to eq(7.5)
  end

  it 'inventory guide: stock_levels_for via external refs, and quantifier counting with a hold' do
    warehouse = create(:stock_location, store: store)
    warehouse.set_external_id('acme_wms', 'WH-1')
    variant.set_external_id('acme_wms', 'SKU-1')

    provider = Class.new(Spree::InventoryProvider::Base) do
      def self.key = 'acme_wms'
      def stock_levels_for(variant, stock_location: nil)
        store = variant.product.store
        locations = stock_location ? [stock_location] : store.stock_locations.active
        warehouses = locations.index_by { |l| l.external_id_for('acme_wms') }.compact
        warehouses.filter_map do |wid, location|
          Spree::StockLevel.new(variant: variant, stock_location: location, count_on_hand: 12, backorderable: false)
        end
      end
    end

    rows = provider.new.stock_levels_for(variant)
    expect(rows.size).to eq(1)
    expect(rows.first.stock_location).to eq(warehouse)
    expect(rows.first).to be_new_record

    cart = create(:cart, store: store)
    li = create(:line_item, order: cart, variant: variant, quantity: 4)
    local = variant.stock_levels.find_or_create_by!(stock_location: warehouse)
    create(:stock_reservation, stock_level: local, line_item: li, cart: cart, quantity: 4)

    expect(Spree::Stock::Quantifier.new(variant, stock_levels: rows).total_on_hand).to eq(8)
  end
end
