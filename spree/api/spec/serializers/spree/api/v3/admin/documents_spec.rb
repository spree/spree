require 'spec_helper'
require 'spree/testing_support/label_provider'

# Customs paperwork reaches the merchant through the provider, not a column,
# so what matters is that both owners of a label actually ask for it: an
# international return is declared like any other export, and for a long
# while only fulfillments exposed it.
RSpec.describe 'admin serializers expose provider documents' do
  let(:store) { @default_store }
  let(:carrier_documents) do
    [Spree::ShippingDocument.new(kind: 'commercial_invoice', url: 'https://carrier.example/invoice.pdf')]
  end

  # A real provider rather than a double: the serializers ask a provider for
  # more than its documents, and a double narrowed to one method only proves
  # the spec author guessed the calls right.
  let(:provider) do
    Spree::TestingSupport::LabelProvider.new.tap do |instance|
      paperwork = carrier_documents
      instance.define_singleton_method(:documents) { |_owner| paperwork }
    end
  end

  describe Spree::Api::V3::Admin::FulfillmentSerializer do
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:fulfillment) { order.fulfillments.first }

    it 'renders what the provider produced beside the label' do
      allow(fulfillment).to receive(:provider).and_return(provider)

      rendered = JSON.parse(described_class.new(fulfillment).serialize)

      expect(rendered['documents']).to eq([{ 'kind' => 'commercial_invoice', 'url' => 'https://carrier.example/invoice.pdf' }])
    end
  end

  describe Spree::Api::V3::Admin::ReturnSerializer do
    let(:return_record) { create(:return, order: create(:shipped_order, store: store)) }

    it 'renders the paperwork for the inbound parcel' do
      allow(return_record).to receive(:provider).and_return(provider)

      rendered = JSON.parse(described_class.new(return_record).serialize)

      expect(rendered['documents']).to eq([{ 'kind' => 'commercial_invoice', 'url' => 'https://carrier.example/invoice.pdf' }])
    end

    it 'is empty rather than absent when the provider produced none' do
      rendered = JSON.parse(described_class.new(return_record).serialize)

      expect(rendered).to have_key('documents')
      expect(rendered['documents']).to eq([])
    end
  end
end
