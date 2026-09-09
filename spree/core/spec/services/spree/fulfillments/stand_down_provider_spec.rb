require 'spec_helper'
require 'spree/testing_support/label_provider'

RSpec.describe Spree::Fulfillments::StandDownProvider do
  subject(:service) { described_class.new }

  let(:store) { @default_store }
  let(:fulfillment) { create(:order_ready_to_ship, store: store).fulfillments.first }
  let(:provider) { Spree::TestingSupport::LabelProvider.new }

  before do
    Spree::TestingSupport::LabelProvider.reset!
    allow(fulfillment).to receive(:provider).and_return(provider)
  end

  it 'refunds every active label, then drops the provider dispatch' do
    label = create(:shipping_label, :with_delivery, owner: fulfillment)
    allow(provider).to receive(:cancel_fulfillment).and_call_original

    expect(service.call(fulfillment: fulfillment)).to be_success
    expect(label.reload).to be_refunded
    expect(provider).to have_received(:cancel_fulfillment).with(fulfillment)
  end

  it 'leaves an uploaded label alone — there is nothing to refund' do
    label = create(:shipping_label, :uploaded, owner: fulfillment)

    service.call(fulfillment: fulfillment)

    expect(label.reload).to be_purchased
  end

  # The goods are not going out either way, so a refused refund never blocks
  # the cancellation — but the merchant is out of pocket, so it is reported.
  it 'reports a refund the carrier refuses without blocking the stand-down' do
    create(:shipping_label, :with_delivery, owner: fulfillment)
    Spree::TestingSupport::LabelProvider.refund_result = false
    allow(Rails.error).to receive(:report)
    allow(provider).to receive(:cancel_fulfillment).and_call_original

    expect(service.call(fulfillment: fulfillment)).to be_success
    expect(Rails.error).to have_received(:report).with(
      instance_of(Spree::Core::LabelRefundFailed), hash_including(source: 'spree.fulfillments.stand_down')
    )
    expect(provider).to have_received(:cancel_fulfillment)
  end
end
