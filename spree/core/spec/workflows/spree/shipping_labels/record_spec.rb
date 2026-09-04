require 'spec_helper'

module Spree
  describe ShippingLabels::Record do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }
    let(:file) do
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("%PDF-1.4\n%label\n"), filename: 'label.pdf', content_type: 'application/pdf',
        service_name: Spree.private_storage_service_name
      ).signed_id
    end

    before { fulfillment.deliveries.destroy_all }

    it 'records an uploaded label with its cost and mints the delivery' do
      result = subject.call(
        owner: fulfillment, file: file, tracking_number: '1Z879E930346834440', cost: 6.5, currency: 'USD'
      )

      expect(result).to be_success
      label = result.value
      expect(label.source).to eq('uploaded')
      expect(label).to be_purchased
      expect(label.format).to eq('pdf')
      expect(label.cost).to eq(6.5)
      expect(label.file).to be_attached
      expect(label.integration).to be_nil
      expect(label.delivery.tracking_number).to eq('1Z879E930346834440')
      expect(label.delivery.carrier).to eq('ups')
      expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
    end

    it 'takes a free-text carrier for a number nothing recognises' do
      result = subject.call(owner: fulfillment, file: file, tracking_number: 'PRO-4471923', carrier: 'Estes Freight')

      expect(result.value.delivery.carrier).to eq('Estes Freight')
    end

    it 'needs a tracking number and a file' do
      expect(subject.call(owner: fulfillment, file: file, tracking_number: '')).to be_failure
      expect(subject.call(owner: fulfillment, file: nil, tracking_number: 'X')).to be_failure
    end

    it 'refuses a second label while one is active' do
      create(:shipping_label, owner: fulfillment)

      result = subject.call(owner: fulfillment, file: file, tracking_number: 'X-1')

      expect(result.error.to_s).to eq(Spree.t('shipping_labels.errors.already_purchased'))
    end

    it 'refuses a file whose bytes are not a label' do
      spoofed = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('<html></html>'), filename: 'label.pdf', content_type: 'application/pdf',
        service_name: Spree.private_storage_service_name
      ).signed_id

      result = subject.call(owner: fulfillment, file: spoofed, tracking_number: 'X-1')

      expect(result).to be_failure
      expect(fulfillment.reload.shipping_labels).to be_empty
      expect(fulfillment.deliveries).to be_empty
    end

    it 'records a label on a return' do
      return_record = create(:return, order: create(:shipped_order, store: store))

      result = subject.call(owner: return_record, file: file, tracking_number: 'RET-1')

      expect(result).to be_success
      expect(return_record.reload.active_shipping_label).to eq(result.value)
    end
  end
end
