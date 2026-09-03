require 'spec_helper'
require 'spree/testing_support/label_provider'

module Spree
  describe ShippingLabels::Purchase do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }
    let(:provider) { Spree::TestingSupport::LabelProvider.new }

    before do
      Spree::TestingSupport::LabelProvider.reset!
      allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(provider)
      fulfillment.deliveries.destroy_all
      allow(SsrfFilter).to receive(:get).and_return(
        Net::HTTPOK.new('1.1', '200', 'OK').tap { |response| allow(response).to receive(:body).and_return("%PDF-1.4\n%label\n") }
      )
    end

    it 'records the label, mints its delivery and stores the file' do
      result = subject.call(owner: fulfillment)

      expect(result).to be_success
      label = result.value
      expect(label).to be_purchased
      expect(label.source).to eq('purchased')
      expect(label.store).to eq(store)
      expect(label.tracking_number).to eq('1Z879E930346834440')
      expect(label.cost).to eq(7.25)
      expect(label.currency).to eq('USD')
      expect(label.metadata).to include('tracker_id' => 'trk_1', 'file_url' => 'https://carrier.example/label.pdf')
      expect(label.file).to be_attached

      delivery = label.delivery
      expect(delivery.tracking_number).to eq('1Z879E930346834440')
      expect(delivery.carrier).to eq('ups')
      expect(delivery.tracking_url).to eq('https://tracker.example/1Z879E930346834440')
      expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
      expect(fulfillment).to be_unfulfilled
    end

    it 'binds the label to a delivery the merchant already typed' do
      Spree::Deliveries::Create.new.call(owner: fulfillment, tracking_number: '1Z879E930346834440')

      subject.call(owner: fulfillment)

      expect(fulfillment.reload.deliveries.count).to eq(1)
      expect(fulfillment.deliveries.first.shipping_label).to eq(fulfillment.active_shipping_label)
    end

    it 'publishes shipping_label.purchased', events: true do
      allow(Spree::Events).to receive(:publish).and_call_original

      subject.call(owner: fulfillment)

      expect(Spree::Events).to have_received(:publish).with('shipping_label.purchased', anything, anything)
    end

    # The purchase is a fact the moment the carrier charged for it; a slow
    # label CDN must not lose it.
    it 'keeps the purchase and retries the file in the background when the fetch fails' do
      allow(SsrfFilter).to receive(:get).and_raise(SocketError.new('down'))

      expect { subject.call(owner: fulfillment) }.to have_enqueued_job(Spree::ShippingLabels::StoreFileJob)

      label = fulfillment.reload.active_shipping_label
      expect(label).to be_present
      expect(label).to be_file_pending
    end

    it 'refuses a second label while one is active — providers are never asked twice' do
      subject.call(owner: fulfillment)
      expect(provider).not_to receive(:purchase_label)

      result = subject.call(owner: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.already_purchased'))
    end

    it 'buys again once the previous label was refunded' do
      subject.call(owner: fulfillment)
      fulfillment.active_shipping_label.update!(status: 'refunded', refunded_at: Time.current)

      expect(subject.call(owner: fulfillment)).to be_success
      expect(fulfillment.reload.shipping_labels.count).to eq(2)
    end

    it 'fails loudly when the provider cannot produce a label' do
      Spree::TestingSupport::LabelProvider.purchase_result = false
      allow(provider).to receive(:purchase_label).and_return(nil)

      result = subject.call(owner: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.label_purchase_failed'))
      expect(fulfillment.reload.shipping_labels).to be_empty
    end

    it 'refuses a provider without labels' do
      allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(Spree::FulfillmentProvider::Manual.new)

      result = subject.call(owner: fulfillment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.provider_has_no_labels'))
    end

    it 'refuses a fulfillment that already shipped' do
      fulfillment.update!(status: 'fulfilled')

      expect(subject.call(owner: fulfillment)).to be_failure
    end

    it 'refuses a draft order' do
      order.update_columns(status: 'draft', completed_at: nil)

      result = subject.call(owner: fulfillment)

      expect(result.error.to_s).to eq(Spree.t('fulfillments.errors.order_draft'))
    end

    describe 'for a return' do
      let(:return_record) { create(:return, order: create(:shipped_order, store: store)) }

      before { allow(return_record).to receive(:provider).and_return(provider) }

      it 'attaches the label and the inbound delivery to the return' do
        result = subject.call(owner: return_record)

        expect(result).to be_success
        expect(return_record.reload.active_shipping_label).to eq(result.value)
        expect(return_record.deliveries.first.tracking_number).to eq('1Z879E930346834440')
        expect(return_record).to be_requested
      end

      it 'refuses a closed return' do
        return_record.update!(status: 'canceled')

        expect(subject.call(owner: return_record)).to be_failure
      end
    end

    describe 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'lets a validate handler veto the purchase before anything is bought' do
        Spree.hooks.register('shipping_labels.purchase.validate') { |flow| flow.reject!('carrier blocked') }
        expect(provider).not_to receive(:purchase_label)

        result = subject.call(owner: fulfillment)

        expect(result).to be_failure
        expect(fulfillment.reload.shipping_labels).to be_empty
      end
    end
    # A provider whose dispatch IS the label must not also be asked to
    # dispatch, or the fulfill path buys a second one.
    it 'is the only provider call the fulfill path makes for a label provider' do
      allow(provider).to receive(:create_fulfillment).and_call_original

      Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment)

      expect(provider).not_to have_received(:create_fulfillment)
      expect(fulfillment.reload.shipping_labels.count).to eq(1)
    end
  end
end
