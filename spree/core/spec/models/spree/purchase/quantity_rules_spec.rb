require 'spec_helper'

RSpec.describe Spree::Purchase::QuantityRules do
  let(:store) { @default_store }
  let(:company) { create(:company, store: store) }
  let(:customer) { create(:user) }
  let(:catalog) { create(:catalog, store: store) }
  let(:cart) { create(:cart, store: store, user: customer, company: company) }

  before do
    create(:company_membership, company: company, customer: customer)
    create(:catalog_assignment, catalog: catalog, assignable: company)
    Spree::Current.applicable_catalogs = nil
  end

  describe 'the order minimum' do
    before { create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500) }

    it 'reads the buyer catalog row for the cart currency' do
      expect(cart.order_minimum_amount).to eq(500)
    end

    it 'reports how far off an empty cart is' do
      expect(cart.order_minimum_shortfall).to eq(500)
      expect(cart).to be_below_order_minimum
    end

    it 'reports nothing left to add once the items reach it' do
      product = create(:product, store: store, price: 600)
      Spree::Carts::AddItem.call(cart: cart, variant: product.default_variant, quantity: 1)

      expect(cart.reload.order_minimum_shortfall).to eq(0)
      expect(cart.reload).not_to be_below_order_minimum
    end

    # Delivery and tax are not what the buyer bought, so a threshold must not
    # be reachable by choosing faster shipping.
    it 'measures the item total rather than the order total' do
      product = create(:product, store: store, price: 100)
      Spree::Carts::AddItem.call(cart: cart, variant: product.default_variant, quantity: 1)

      expect(cart.reload.order_minimum_shortfall).to eq(400)
    end

    it 'is silent for a currency no catalog prices' do
      cart.update!(currency: 'GBP')

      expect(cart.reload.order_minimum).to be_nil
      expect(cart.reload).not_to be_below_order_minimum
    end
  end

  describe 'a buyer with no catalogs' do
    let(:cart) { create(:cart, store: store) }

    it 'has no minimum' do
      expect(cart.order_minimum).to be_nil
      expect(cart).not_to be_below_order_minimum
    end
  end

  describe '#line_items_violating_quantity_rules' do
    let(:product) { create(:product, store: store, price: 10) }
    let(:variant) { product.default_variant }

    before do
      Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 3)
    end

    it 'is empty while every line still fits' do
      expect(cart.reload.line_items_violating_quantity_rules).to be_empty
    end

    it 'names a line the terms no longer admit, with the rule it breaks' do
      create(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                     minimum_order_quantity: 48, order_multiple: 24)
      Spree::Current.applicable_catalogs = nil

      line_item, rule = cart.reload.line_items_violating_quantity_rules.first

      expect(line_item.variant).to eq(variant)
      expect(rule.minimum).to eq(48)
    end
  end
end
