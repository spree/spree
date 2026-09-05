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

  # The order exists to be shipped. A guard reading "paid in full" would make
  # every deposit order undispatchable, which is the deposit made useless.
  it 'can be dispatched having paid only the deposit' do
    create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')
    order = Spree::Carts::Complete.call(cart: cart.reload).value
    fulfillment = order.fulfillments.first
    fulfillment.fulfillment_items.each do |item|
      fulfillment.stock_location.stock_level_or_create(item.variant).set_count_on_hand(100)
    end

    result = Spree::Fulfillments::Fulfill.call(fulfillment: fulfillment.reload)

    expect(result).to be_success
  end

  # The forwarder's charge arrives after placement. It raises what is owed;
  # it must not raise what the buyer already agreed to pay up front.
  it 'keeps the deposit measured against the total it was struck against' do
    create(:payment, cart: cart, order: nil, amount: cart.reload.amount_due_at_checkout, status: 'completed')
    order = Spree::Carts::Complete.call(cart: cart.reload).value
    agreed = order.amount_due_at_checkout

    create(:fee, order: order, amount: 500)
    Spree::Orders::RecalculateTotals.call(order: order.reload)

    expect(order.reload.amount_due_at_checkout).to eq(agreed)
    expect(order.outstanding_balance).to be > 0
  end

  # Carts split per delivery profile, so a wholesale buyer adding one parcel
  # item gets two shipments. The deposit must survive that.
  it 'finds the deposit on a cart that also ships a parcel' do
    parcel_method = create(:delivery_method, store: store)
    parcel = create(:shipment, cart: cart, order: nil)
    parcel.update_columns(created_at: 1.hour.ago)
    create(:delivery_rate, fulfillment: parcel, delivery_method: parcel_method, selected: true)
    Spree::Carts::RecalculateTotals.call(cart: cart.reload)

    schedule = cart.reload.payment_schedule

    expect(schedule.deposit_amount).to be_present
    expect(schedule.balance_due_label).to eq('Before shipping')
  end

  # A payment built without an explicit amount must ask for the deposit. If it
  # defaulted to the total the buyer would be charged in full and the deposit
  # would exist only on screen.
  it 'charges the deposit when no amount is given' do
    payment = cart.reload.payments.build(payment_method: create(:check_payment_method, store: store))
    payment.valid?

    expect(payment.amount).to eq(cart.amount_due_at_checkout)
    expect(payment.amount).to be < cart.total
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
