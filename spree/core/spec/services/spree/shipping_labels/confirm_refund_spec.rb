require 'spec_helper'

RSpec.describe Spree::ShippingLabels::ConfirmRefund do
  subject(:service) { described_class.new }

  let(:fulfillment) { create(:order_ready_to_ship, store: @default_store).fulfillments.first }

  it 'settles a refund the carrier answered later', events: true do
    label = create(:shipping_label, owner: fulfillment, status: 'refund_requested')
    allow(Spree::Events).to receive(:publish).and_call_original

    result = service.call(shipping_label: label, refunded_at: 1.hour.ago)

    expect(result).to be_success
    expect(label.reload).to be_refunded
    expect(label.refunded_at).to be_within(1.second).of(1.hour.ago)
    expect(Spree::Events).to have_received(:publish).with('shipping_label.refunded', anything, anything)
  end

  it 'refuses a label the carrier was never asked about' do
    label = create(:shipping_label, owner: fulfillment)

    expect(service.call(shipping_label: label)).to be_failure
    expect(label.reload).to be_purchased
  end
end
