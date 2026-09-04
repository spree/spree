require 'spec_helper'
require 'spree/testing_support/label_provider'

module Spree
  describe ShippingLabels::Refund do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }
    let(:provider) { Spree::TestingSupport::LabelProvider.new }
    let!(:label) { create(:shipping_label, :with_delivery, owner: fulfillment) }

    before do
      Spree::TestingSupport::LabelProvider.reset!
      allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(provider)
    end

    it 'records a refund the carrier settles at once and removes the unshipped delivery', events: true do
      allow(Spree::Events).to receive(:publish).and_call_original

      result = subject.call(shipping_label: label)

      expect(result).to be_success
      expect(label.reload).to be_refunded
      expect(label.refunded_at).to be_present
      expect(label.delivery).to be_nil
      expect(fulfillment.reload.active_shipping_label).to be_nil
      expect(Spree::Events).to have_received(:publish).with('shipping_label.refunded', anything, anything)
    end

    it 'waits when the carrier answers later' do
      Spree::TestingSupport::LabelProvider.refund_result = 'refund_requested'

      subject.call(shipping_label: label)

      expect(label.reload).to be_refund_requested
      expect(label.refunded_at).to be_nil
    end

    # Once the parcel moved, the journey is history whatever happened to the
    # postage.
    it 'keeps the delivery when the parcel already shipped' do
      fulfillment.update!(status: 'fulfilled', fulfilled_at: Time.current)

      subject.call(shipping_label: label)

      expect(label.reload).to be_refunded
      expect(label.delivery).to be_present
    end

    it 'fails when the carrier refuses' do
      Spree::TestingSupport::LabelProvider.refund_result = false

      result = subject.call(shipping_label: label)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.refund_failed'))
      expect(label.reload).to be_purchased
    end


    it 'refuses an uploaded label' do
      # Its own parcel: one live label per parcel is a database constraint,
      # and this fulfillment already carries the purchased one above.
      uploaded = create(:shipping_label, :uploaded, owner: create(:fulfillment, order: order, tracking: nil))

      result = subject.call(shipping_label: uploaded)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.uploaded_not_refundable'))
    end

    it 'refuses a label already refunded' do
      label.update!(status: 'refunded', refunded_at: Time.current)

      expect(subject.call(shipping_label: label)).to be_failure
    end
  end
end
