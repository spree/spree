require 'spec_helper'
RSpec.describe Spree::Carts::AddItem, 'with an external pricing provider' do
  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:variant) { create(:variant, price: 20) }
  let(:klass) do
    Class.new(Spree::PricingProvider::Base) do
      class << self; attr_accessor :calls; end
      self.calls = 0
      def self.key = 'contract'
      def price_for(ctx)
        self.class.calls += 1
        Spree::Price.new(variant: ctx.variant, currency: ctx.currency, amount: 5)
      end
    end
  end
  before { Spree.pricing_providers << klass; stub_store_preferences(store, pricing_provider: 'contract') }
  after { Spree.pricing_providers.delete(klass) }

  # The second add increments an existing line; the quantity-change callback
  # used to ask the provider again from inside the transaction.
  it 'asks the provider once per add, even when incrementing an existing line' do
    Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 1)
    klass.calls = 0

    Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 1)

    expect(klass.calls).to eq(1)
    expect(cart.line_items.reload.first.price).to eq(5)
    expect(cart.line_items.first.quantity).to eq(2)
  end
end
