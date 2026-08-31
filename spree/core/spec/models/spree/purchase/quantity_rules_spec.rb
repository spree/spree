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
    Spree::Current.reset_catalog_memos
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

  describe '#quantity_rule_violations' do
    let(:product) { create(:product, store: store, price: 10) }
    let(:variant) { product.default_variant }

    before do
      Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: 3)
    end

    it 'is empty while every line still fits' do
      expect(cart.reload.quantity_rule_violations).to be_empty
    end

    it 'names a line the terms no longer admit, in the words add-to-cart used' do
      create(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                     minimum_order_quantity: 48, order_multiple: 24)
      Spree::Current.reset_catalog_memos

      line_item, message = cart.reload.quantity_rule_violations.first

      expect(line_item.variant).to eq(variant)
      expect(message).to include('48')
    end

    # Staff key in what the buyer negotiated, so a draft order is never
    # refused at completion for a quantity they deliberately entered.
    it 'is empty for a staff-keyed purchase' do
      create(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                     minimum_order_quantity: 48, order_multiple: 24)
      Spree::Current.reset_catalog_memos
      allow(cart).to receive(:staff_initiated?).and_return(true)

      expect(cart.quantity_rule_violations).to be_empty
    end
  end
end
