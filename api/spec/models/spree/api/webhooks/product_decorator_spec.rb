require 'spec_helper'

describe Spree::Api::Webhooks::ProductDecorator do
  let(:product) { create(:product) }
  let(:webhook_payload_body) do
    Spree::Api::V2::Platform::ProductSerializer.new(
      product,
      include: Spree::Api::V2::Platform::ProductSerializer.relationships_to_serialize.keys
    ).serializable_hash
  end
  let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }

  context 'emitting product.discontinued' do
    let(:event_name) { 'product.discontinued' }

    context 'when product discontinued_on changes' do
      context 'when the new value is "present"' do
        it do
          expect do
            product.discontinue!
          end.to emit_webhook_event(event_name)
        end
      end

      context 'when the new value is not "present"' do
        before { product.update(discontinue_on: Date.yesterday) }

        it do
          expect do
            product.update(discontinue_on: nil)
          end.not_to emit_webhook_event(event_name)
        end
      end
    end

    context 'when product discontinued_on does not change' do
      it do
        expect do
          product.update(width: 180)
        end.not_to emit_webhook_event(event_name)
      end
    end
  end

  context 'when changing status' do
    context 'to active' do
      let(:event_name) { 'product.activated' }

      before { product.update_column(:status, :draft) }

      it do
        expect { product.activate }.to emit_webhook_event(event_name)
      end
    end

    context 'to draft' do
      let(:event_name) { 'product.drafted' }

      it do
        expect { product.draft }.to emit_webhook_event(event_name)
      end
    end

    context 'to archived' do
      let(:event_name) { 'product.archived' }

      it do
        expect { product.archive }.to emit_webhook_event(event_name)
      end
    end
  end
end
