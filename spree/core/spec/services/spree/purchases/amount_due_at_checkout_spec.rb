require 'spec_helper'

RSpec.describe Spree::Purchases::AmountDueAtCheckout do
  let(:store) { @default_store }

  describe 'the open-source answer' do
    it 'is the whole total, so a buyer pays for what they are taking' do
      order = create(:order, store: store)
      create(:line_item, order: order, price: 100, quantity: 2)
      Spree::Orders::RecalculateTotals.call(order: order.reload)

      expect(order.reload.amount_due_at_checkout).to eq(order.total)
    end

    it 'answers for a cart the same way it does for an order' do
      cart = create(:cart, store: store)
      create(:line_item, cart: cart, order: nil, price: 100, quantity: 1)
      Spree::Carts::RecalculateTotals.call(cart: cart.reload)

      expect(cart.reload.amount_due_at_checkout).to eq(cart.total)
    end
  end

  # The point of the class: an arrangement that collects part of the total up
  # front is honoured by checkout and dispatch without either being patched.
  describe 'a replacement that collects part of the total' do
    let(:half_up_front) do
      Class.new do
        def call(purchase:)
          purchase.total.to_d / 2
        end
      end
    end

    around do |example|
      original = Spree::Dependencies.purchase_amount_due_at_checkout_service
      Spree::Dependencies.purchase_amount_due_at_checkout_service = half_up_front
      example.run
    ensure
      Spree::Dependencies.purchase_amount_due_at_checkout_service = original
      Spree::Dependencies.instance_variable_get(:@overrides)&.delete(:purchase_amount_due_at_checkout_service)
    end

    let(:cart) do
      create(:cart, store: store, email: 'buyer@example.com').tap do |cart|
        address = create(:address)
        cart.update!(ship_address: address, bill_address: address)
        create(:line_item, cart: cart, order: nil, price: 100, quantity: 1)
        create(:shipment, cart: cart, order: nil)
        Spree::Carts::RecalculateTotals.call(cart: cart.reload)
      end
    end

    it 'lets checkout stop asking once that part has been paid' do
      create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')

      requirements = Spree::Checkout::DefaultRequirements.new(cart.reload).call

      expect(cart.amount_due_at_checkout).to be < cart.total
      expect(requirements).not_to include(a_hash_including(step: 'payment', field: 'payment'))
    end

    it 'completes the order owing the rest' do
      create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')

      result = Spree::Carts::Complete.call(cart: cart.reload)

      expect(result).to be_success
      expect(result.value).to be_completed
      expect(result.value.outstanding_balance).to be > 0
    end

    it 'dispatches an order that has paid only that part' do
      create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')
      order = Spree::Carts::Complete.call(cart: cart.reload).value
      fulfillment = order.fulfillments.first
      fulfillment.inventory_units.each do |item|
        fulfillment.stock_location.stock_level_or_create(item.variant).update_column(:count_on_hand, 10)
      end

      result = Spree::Fulfillments::Fulfill.call(fulfillment: fulfillment)

      expect(result).to be_success
      expect(order.reload.outstanding_balance).to be > 0
    end

    # The guard still has to refuse an underpaid order — the replacement moves
    # the line, it does not remove it.
    it 'still refuses a cart that has paid less than its arrangement asks' do
      create(:payment, cart: cart, order: nil, amount: 1, status: 'completed')

      expect(Spree::Carts::Complete.call(cart: cart.reload)).to be_failure
    end
  end
end
