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
  # Same rule as the synchronous refund: postage voided before the parcel
  # moved leaves no consignment behind.
  it 'drops the consignment when the parcel never shipped' do
    label = create(:shipping_label, :with_delivery, owner: fulfillment, status: 'refund_requested')

    service.call(shipping_label: label)

    expect(label.reload).to be_refunded
    expect(label.delivery).to be_nil
  end

  it 'keeps the consignment once the parcel has travelled' do
    label = create(:shipping_label, :with_delivery, owner: fulfillment, status: 'refund_requested')
    fulfillment.update!(status: 'fulfilled', fulfilled_at: Time.current)

    service.call(shipping_label: label)

    expect(label.reload.delivery).to be_present
  end
end
