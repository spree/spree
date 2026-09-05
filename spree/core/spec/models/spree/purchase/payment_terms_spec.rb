require 'spec_helper'

RSpec.describe Spree::Purchase::PaymentTerms do
  let(:store) { @default_store }
  let(:freight_method) do
    create(:delivery_method, store: store, rate_provider: 'Spree::DeliveryRateProvider::Freight',
                             deposit_percentage: 40, balance_due_label: 'Before shipping')
  end

  describe 'a retail cart' do
    let(:cart) { create(:cart, store: store) }

    before { create(:line_item, cart: cart, order: nil, price: 100, quantity: 1) }

    it 'owes its whole total, as every order did before deposits' do
      Spree::Carts::RecalculateTotals.call(cart: cart.reload)

      expect(cart.payment_terms_snapshot).to be_nil
      expect(cart.amount_due_at_checkout).to eq(cart.total)
    end
  end

  describe 'a cart shipping on a freight method that asks a deposit' do
    let(:cart) { create(:cart, store: store) }

    before do
      create(:line_item, cart: cart, order: nil, price: 100, quantity: 1)
      fulfillment = create(:shipment, cart: cart, order: nil)
      create(:delivery_rate, fulfillment: fulfillment, delivery_method: freight_method,
                             selected: true, unpriced: true)
      Spree::Carts::RecalculateTotals.call(cart: cart.reload)
    end

    it 'owes the deposit at checkout, not the total' do
      expect(cart.reload.amount_due_at_checkout).to eq(cart.total * BigDecimal('0.4'))
    end

    it 'tells the money story through its schedule' do
      schedule = cart.reload.payment_schedule

      expect(schedule.deposit_amount).to eq(cart.total * BigDecimal('0.4'))
      expect(schedule.balance_due_label).to eq('Before shipping')
      expect(schedule).to be_outstanding
      expect(schedule.deposit_paid).to be(false)
    end

    # The terms follow what the buyer is actually shipping under.
    it 'stops asking for a deposit when the freight rate is deselected' do
      cart.fulfillments.flat_map(&:delivery_rates).each { |rate| rate.update!(selected: false) }

      expect(cart.reload.amount_due_at_checkout).to eq(cart.total)
    end
  end

  describe 'an order' do
    let(:order) { create(:order, store: store) }

    it 'reads the snapshot it was placed with, never the live method' do
      order.update!(payment_terms: { 'kind' => 'deposit', 'deposit_percentage' => '40',
                                     'balance_due_label' => 'Before shipping' })
      create(:line_item, order: order, price: 100, quantity: 1)
      Spree::Orders::RecalculateTotals.call(order: order.reload)

      # The method's terms change afterwards; the order must not follow.
      freight_method.update!(deposit_percentage: 90)

      expect(order.reload.amount_due_at_checkout).to eq(order.total * BigDecimal('0.4'))
    end

    it 'owes its whole total without a snapshot' do
      create(:line_item, order: order, price: 100, quantity: 1)
      Spree::Orders::RecalculateTotals.call(order: order.reload)

      expect(order.amount_due_at_checkout).to eq(order.total)
    end
  end
end
