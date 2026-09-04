require 'spec_helper'
require 'spree/testing_support/label_provider'

module Spree
  describe Fulfillments::PurchaseLabel do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }

    before do
      Spree::TestingSupport::LabelProvider.reset!
      allow(fulfillment).to receive(:provider).and_return(Spree::TestingSupport::LabelProvider.new)
      allow(SsrfFilter).to receive(:get).and_raise(SocketError.new('offline'))
      # The factory seeds a tracking number; a parcel awaiting its label has none.
      fulfillment.deliveries.destroy_all
    end

    it 'buys the label and attaches tracking without fulfilling' do
      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_success
      expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
      expect(fulfillment.active_shipping_label).to be_present
      expect(fulfillment).to be_unfulfilled
    end

    it 'pins the carrier the provider sold the label for' do
      subject.call(fulfillment: fulfillment)

      expect(fulfillment.reload.primary_delivery.carrier).to eq('ups')
    end

    # The one-click fulfill degrades a label failure; here nothing has left
    # the building, so failing loudly is the point.
    it 'fails when the provider cannot produce a label' do
      allow(fulfillment.provider).to receive(:purchase_label).and_return(nil)

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.label_purchase_failed'))
      expect(fulfillment.reload).to be_unfulfilled
    end

    it 'refuses a provider without labels' do
      allow(fulfillment).to receive(:provider).and_return(Spree::FulfillmentProvider::Manual.new)

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.provider_has_no_labels'))
    end

    it 'refuses a second label while one is active' do
      subject.call(fulfillment: fulfillment)

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.already_purchased'))
    end

    it 'refuses a fulfillment that already shipped' do
      fulfillment.update!(status: 'fulfilled')

      expect(subject.call(fulfillment: fulfillment)).to be_failure
    end

    it 'binds the label to a merchant-entered tracking number' do
      Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: '1Z879E930346834440')

      subject.call(fulfillment: fulfillment)

      expect(fulfillment.reload.deliveries.count).to eq(1)
      expect(fulfillment.primary_delivery.shipping_label).to be_present
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'runs its own hooks around the purchase' do
        seen = []
        Spree.hooks.register('fulfillments.purchase_label.after_purchase_label') { |flow| seen << flow.fulfillment }

        subject.call(fulfillment: fulfillment)

        expect(seen).to eq([fulfillment])
      end
    end
  end
end
