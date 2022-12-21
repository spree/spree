require 'spec_helper'

describe Spree::Webhooks::EventSignature do
  subject(:signature) { described_class.new(webhook_event, event_payload) }

  let(:event_payload) { { event_name: 'order.create', data: { id: 123 } } }
  let(:webhook_event) { create(:webhook_event) }

  describe '#computed_signature' do
    it 'computes a unique signature per payload' do
      order_finished_signature =
        described_class.new(webhook_event, { event_name: 'order.finished', data: { id: 123 } })

      expect(signature.computed_signature).
        not_to eq(order_finished_signature.computed_signature)
    end

    it 'computes a stable signature for the same payload' do
      order_created_signature = described_class.new(webhook_event, event_payload)

      expect(signature.computed_signature).
        to eq(order_created_signature.computed_signature)
    end
  end
end
