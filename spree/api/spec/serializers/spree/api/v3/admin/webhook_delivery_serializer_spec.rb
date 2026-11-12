require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::WebhookDeliverySerializer do
  let(:store) { @default_store }
  let(:endpoint) { create(:webhook_endpoint, store: store) }
  let(:delivery) do
    create(:webhook_delivery, webhook_endpoint: endpoint,
                              payload: { 'name' => 'customer.created',
                                         'data' => { 'email' => 'customer@example.com' } })
  end

  # The payload holds the event body, so reading it means reading the record
  # the event is about. Whoever renders this serializer has to say the caller
  # may do that; a reader that says nothing is a reader that did not check.
  describe 'the payload gate' do
    it 'is withheld when no gate is supplied' do
      expect(described_class.new(delivery).to_h['payload']).to be_nil
    end

    it 'is withheld when the gate refuses' do
      serializer = described_class.new(delivery, params: { payload_visible: ->(_delivery) { false } })

      expect(serializer.to_h['payload']).to be_nil
    end

    it 'is rendered when the gate allows' do
      serializer = described_class.new(delivery, params: { payload_visible: ->(_delivery) { true } })

      expect(serializer.to_h['payload']).to include('name' => 'customer.created')
    end
  end
end
