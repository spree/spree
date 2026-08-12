require 'spec_helper'

module Spree
  describe Fulfillments::PurchaseLabel do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }

    let(:label_provider_class) do
      Class.new(Spree::FulfillmentProvider::Base) do
        def self.generates_labels?
          true
        end

        def create_fulfillment(_fulfillment)
          { tracking_number: '1Z879E930346834440', tracking_url: 'https://carrier.example/t/1' }
        end
      end
    end

    before do
      allow(fulfillment).to receive(:provider).and_return(label_provider_class.new)
      # The factory seeds a tracking number; a parcel awaiting its label has none.
      fulfillment.update_column(:tracking, nil)
    end

    it 'buys the label and attaches tracking without fulfilling' do
      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_success
      expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
      expect(fulfillment).to be_unfulfilled
    end

    it 'pins the carrier detected from the purchased number' do
      subject.call(fulfillment: fulfillment)

      expect(fulfillment.reload.tracking_carrier).to eq('ups')
    end

    # The one-click fulfill degrades a label failure; here nothing has left
    # the building, so failing loudly is the point.
    it 'fails when the provider cannot produce a label' do
      allow(fulfillment.provider).to receive(:create_fulfillment).and_return({})

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.label_purchase_failed'))
      expect(fulfillment.reload).to be_unfulfilled
    end

    it 'refuses a provider without labels' do
      allow(fulfillment).to receive(:provider).and_return(Spree::FulfillmentProvider::Manual.new)

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.provider_has_no_labels'))
    end

    it 'refuses a fulfillment that already shipped' do
      fulfillment.update!(status: 'fulfilled')

      expect(subject.call(fulfillment: fulfillment)).to be_failure
    end

    it 'refuses a draft order' do
      order.update_columns(status: 'draft', completed_at: nil)

      result = subject.call(fulfillment: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.order_draft'))
    end

    it 'keeps a merchant-entered tracking number' do
      fulfillment.update!(tracking: 'MERCHANT-123')

      subject.call(fulfillment: fulfillment)

      expect(fulfillment.reload.tracking).to eq('MERCHANT-123')
    end
  end
end
