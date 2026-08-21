require 'spec_helper'

# Dispatching a parcel in a split checkout draws on a payment several orders
# share, so what it may take is bounded by this order's own recorded share.
RSpec.describe Spree::Fulfillment, 'capture on dispatch in a split checkout' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:group) { create(:order_group, store: store) }

  let!(:seller_order) { create(:order, store: store, order_group: group, seller: seller, total: 40) }
  let!(:first_party_order) { create(:order, store: store, order_group: group, total: 60) }

  let(:payment_method) { create(:check_payment_method, store: store, capture_method: 'on_dispatch') }
  let(:payment) do
    create(:payment, order: nil, cart: nil, order_group: group, amount: 100,
                     status: 'pending', payment_method: payment_method)
  end

  let!(:seller_split) do
    create(:payment_split, payment: payment, order: seller_order, authorized_amount: 40)
  end
  let!(:first_party_split) do
    create(:payment_split, payment: payment, order: first_party_order, authorized_amount: 60)
  end

  # A parcel worth more than this order's share of the shared payment.
  def dispatch(order, worth:)
    fulfillment = create(:fulfillment, order: order, cart: nil)
    allow(fulfillment).to receive(:final_price_with_items).and_return(BigDecimal(worth))
    fulfillment.send(:process_order_payments)
    fulfillment
  end

  before { payment }

  it 'captures no more than the order’s own share' do
    dispatch(seller_order, worth: 100)

    expect(captured_for(seller_order)).to eq(40)
  end

  # A partial capture forks the payment, and the uncaptured shares move to the
  # remainder with the money — so an order's position is the sum of its shares
  # across every payment the group holds, not one row.
  def captured_for(order)
    order.payment_splits.sum(:captured_amount)
  end

  def authorized_for(order)
    order.payment_splits.sum(:authorized_amount)
  end

  it 'leaves the sibling’s money untouched and still capturable' do
    dispatch(seller_order, worth: 100)

    expect(captured_for(first_party_order)).to eq(0)
    expect(authorized_for(first_party_order)).to eq(60)
  end

  it 'lets each order capture its own share in turn' do
    dispatch(seller_order, worth: 40)
    dispatch(first_party_order, worth: 60)

    expect(captured_for(seller_order)).to eq(40)
    expect(captured_for(first_party_order)).to eq(60)
  end

  it 'takes nothing more once the share is used up' do
    dispatch(seller_order, worth: 40)

    expect { dispatch(seller_order, worth: 40) }.not_to change { captured_for(seller_order) }
  end

  it 'reports the order as paid once its share is captured' do
    dispatch(seller_order, worth: 40)
    Spree::Orders::UpdateStatuses.call(order: seller_order)

    expect(seller_order.reload.payment_status).to eq('paid')
  end
end
