require 'spec_helper'
require 'spree/testing_support/label_provider'

module Spree
  describe Returns::PurchaseLabel do
    subject { described_class }

    let(:store) { @default_store }
    let(:return_record) { create(:return, order: create(:shipped_order, store: store)) }

    before do
      Spree::TestingSupport::LabelProvider.reset!
      allow(return_record).to receive(:provider).and_return(Spree::TestingSupport::LabelProvider.new)
      allow(SsrfFilter).to receive(:get).and_raise(SocketError.new('offline'))
    end

    it 'buys the return label and records the inbound consignment' do
      result = subject.call(return_record: return_record)

      expect(result).to be_success
      expect(return_record.reload.active_shipping_label.tracking_number).to eq('1Z879E930346834440')
      expect(return_record.deliveries.first.tracking_number).to eq('1Z879E930346834440')
      expect(return_record).to be_requested
    end

    it 'passes the purchase failure through' do
      allow(return_record.provider).to receive(:purchase_label).and_return(nil)

      result = subject.call(return_record: return_record)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.label_purchase_failed'))
    end

    it 'ships through the provider of the outbound parcel' do
      allow(return_record).to receive(:provider).and_call_original

      expect(return_record.provider).to be_a(Spree::FulfillmentProvider::Base)
    end
  end
end
