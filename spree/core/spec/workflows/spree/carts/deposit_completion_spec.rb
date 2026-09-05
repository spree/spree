require 'spec_helper'

RSpec.describe 'completing a cart that owes a deposit' do
  let(:store) { @default_store }
  let(:freight_method) do
    create(:delivery_method, store: store, rate_provider: 'Spree::DeliveryRateProvider::Freight',
                             deposit_percentage: 40, balance_due_label: 'Before shipping')
  end
  let(:cart) { create(:cart, store: store, email: 'buyer@example.com') }

  before do
    address = create(:address)
    cart.update!(ship_address: address, bill_address: address)
    create(:line_item, cart: cart, order: nil, price: 100, quantity: 1)
    fulfillment = create(:shipment, cart: cart, order: nil)
    create(:delivery_rate, fulfillment: fulfillment, delivery_method: freight_method,
                           selected: true, unpriced: true)
    Spree::Carts::RecalculateTotals.call(cart: cart.reload)
  end

  # The point of the whole phase: a buyer pays 40% and the order is placed
  # owing the rest, rather than being refused for underpaying.
  it 'completes on the deposit alone and carries the balance' do
    create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')

    result = Spree::Carts::Complete.call(cart: cart.reload)

    expect(result).to be_success
    order = result.value
    expect(order).to be_completed
    expect(order.outstanding_balance).to be > 0
    expect(order.payment_status).to eq('partially_paid')
  end

  it 'freezes the terms it was placed under' do
    create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')

    order = Spree::Carts::Complete.call(cart: cart.reload).value

    expect(order.payment_terms['kind']).to eq('deposit')
    expect(order.payment_terms['deposit_percentage'].to_d).to eq(40)
    expect(order.payment_schedule.balance_due_label).to eq('Before shipping')
  end

  # A retail order still has to cover everything — the deposit path must not
  # let an underpaid parcel order through.
  it 'still refuses a cart that owes its whole total and underpays' do
    address = create(:address)
    retail = create(:cart, store: store, email: 'shopper@example.com',
                           ship_address: address, bill_address: address)
    create(:line_item, cart: retail, order: nil, price: 100, quantity: 1)
    Spree::Carts::RecalculateTotals.call(cart: retail.reload)
    create(:payment, cart: retail, order: nil, amount: 1, status: 'completed')

    result = Spree::Carts::Complete.call(cart: retail.reload)

    expect(result).not_to be_success
  end
end
