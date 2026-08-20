require 'spec_helper'

RSpec.describe Spree::Carts::PriceItems do
  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:variant) { create(:variant, price: 20) }

  let(:external_provider_class) do
    Class.new(Spree::PricingProvider::Base) do
      class << self
        attr_accessor :amount, :fail_with, :calls
      end
      self.amount = 5
      self.calls = 0

      def self.key = 'contract'

      def price_for(context)
        self.class.calls += 1
        raise self.class.fail_with if self.class.fail_with

        Spree::Price.new(variant: context.variant, currency: context.currency, amount: self.class.amount)
      end
    end
  end

  describe 'with Spree own catalog' do
    it 'prices from the catalog and records no provider' do
      line_item = create(:line_item, order: cart, variant: variant, quantity: 1)

      result = described_class.new.call(cart: cart, line_items: [line_item])
      described_class.apply(result.value)

      expect(line_item.reload.price).to eq(20)
      expect(line_item.price_source).to be_nil
    end

    it 'never re-prices a completed order — what it sold at is a fact, not a question' do
      order = create(:completed_order_with_totals, store: store)
      line_item = order.line_items.first
      original = line_item.price
      line_item.variant.prices.each { |price| price.update!(amount: 999) }

      result = described_class.new.call(cart: order, line_items: [line_item])
      described_class.apply(result.value)

      expect(line_item.reload.price).to eq(original)
    end

    # The freeze covers what was sold, not what is being added: an admin
    # amending a placed order still needs the new line priced through the
    # price lists (and a provider), or a contract customer is billed list.
    it 'still prices a line being added to a completed order' do
      order = create(:completed_order_with_totals, store: store)
      price_list = create(:price_list, :active, store: store)
      create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 15)
      new_line = order.line_items.new(variant: variant, quantity: 1, currency: 'USD')

      result = described_class.new.call(cart: order, line_items: [new_line])
      described_class.apply(result.value)

      expect(new_line.price).to eq(15)
      expect(new_line.price_list_id).to eq(price_list.id)
    end
  end

  describe 'with an external provider' do
    before do
      stub_const('SpreeTest::ContractProvider', external_provider_class)
      external_provider_class.fail_with = nil
      external_provider_class.calls = 0
      Spree.pricing_providers << external_provider_class
      stub_store_preferences(store, pricing_provider: 'contract')
    end

    after { Spree.pricing_providers.delete(external_provider_class) }

    it 'writes the provider price and names the provider on the line' do
      line_item = create(:line_item, order: cart, variant: variant, quantity: 1)

      result = described_class.new.call(cart: cart, line_items: [line_item])
      described_class.apply(result.value)

      expect(line_item.reload.price).to eq(5)
      expect(line_item.price_source).to eq('contract')
    end

    it 'asks once per line and no more, so a large cart is one round per item' do
      3.times { create(:line_item, order: cart, variant: create(:variant), quantity: 1) }

      described_class.new.call(cart: cart)

      expect(external_provider_class.calls).to eq(3)
    end

    it 'refuses to price when the provider is down and the store is strict' do
      external_provider_class.fail_with = Timeout::Error
      line_item = create(:line_item, order: cart, variant: variant, quantity: 1)

      result = described_class.new.call(cart: cart, line_items: [line_item])

      expect(result).to be_failure
    end

    it 'falls back to the catalog price when the store opts into that, and says so on the line' do
      external_provider_class.fail_with = Timeout::Error
      stub_store_preferences(store, pricing_provider: 'contract', pricing_provider_failure_policy: 'fallback')
      line_item = create(:line_item, order: cart, variant: variant, quantity: 1)

      result = described_class.new.call(cart: cart, line_items: [line_item])
      described_class.apply(result.value)

      expect(result).to be_success
      expect(line_item.reload.price).to eq(20)
      # Priced from the catalog, so the line must not claim the provider did it.
      expect(line_item.price_source).to be_nil
    end
  end

  describe 'applying' do
    it 'leaves a line item alone when the price has not moved' do
      line_item = create(:line_item, order: cart, variant: variant, quantity: 1)
      result = described_class.new.call(cart: cart, line_items: [line_item])
      described_class.apply(result.value)
      before = line_item.reload.updated_at

      described_class.apply(result.value)

      expect(line_item.reload.updated_at).to eq(before)
    end

    it 'assigns without saving for a line item that does not exist yet' do
      line_item = cart.line_items.new(variant: variant, quantity: 1, currency: cart.currency)

      result = described_class.new.call(cart: cart, line_items: [line_item])
      described_class.apply(result.value)

      expect(line_item.price).to eq(20)
      expect(line_item).to be_new_record
    end
  end
end
