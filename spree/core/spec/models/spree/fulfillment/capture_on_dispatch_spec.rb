require 'spec_helper'

# The order total can come down after the payment was authorized — a line
# removed, a discount added — so a parcel can be worth more than the order
# still owes. Dispatch then captures the balance rather than failing.
RSpec.describe Spree::Fulfillment, 'capture on dispatch after the order total came down' do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 100) }
  let(:payment_method) { create(:check_payment_method, store: store, capture_method: 'on_dispatch') }
  let!(:payment) { create(:payment, order: order, amount: 100, status: 'pending', payment_method: payment_method) }

  before { order.update_columns(total: 80) }

  it 'captures what the order still owes and releases the rest' do
    fulfillment = create(:fulfillment, order: order, cart: nil)
    allow(fulfillment).to receive(:final_price_with_items).and_return(BigDecimal('100'))

    fulfillment.send(:process_order_payments)

    expect(payment.reload).to be_completed
    expect(payment.captured_amount).to eq(80)
    expect(order.payments.pending).to be_empty
  end
end
