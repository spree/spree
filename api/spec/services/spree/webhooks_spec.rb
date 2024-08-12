require 'spec_helper'

describe Spree::Webhooks do
  describe '#disable_webhooks' do
    let(:webhook_payload_body) do
      Spree::Api::V2::Platform::VariantSerializer.new(
        variant,
        include: Spree::Api::V2::Platform::VariantSerializer.relationships_to_serialize.keys
      ).serializable_hash
    end
    let(:event_name) { 'variant.discontinued' }
    let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }
    let(:variant) { create(:variant) }

    before do
      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    after { Spree::Webhooks.disabled = true }

    describe 'the value of spree_webhooks_disabled request variable' do
      before { RequestStore.store[:disable_spree_webhooks] = false }

      describe 'when an error is not raised' do
        it 'sets it to the original value' do
          described_class.disable_webhooks { variant.discontinue! }
          expect(RequestStore.store[:disable_spree_webhooks]).to eq(false)
        end
      end

      describe 'when an error is raised' do
        it 'sets it to the original value' do
          begin
            described_class.disable_webhooks { raise StandardError }
          rescue StandardError
          end
          expect(RequestStore.store[:disable_spree_webhooks]).to eq(false)
        end
      end
    end

    describe 'when webhooks are already disabled' do
      before { Spree::Webhooks.disabled = true }

      it 'does not emit the event' do
        described_class.disable_webhooks { variant.discontinue! }
        expect(queue_requests).not_to have_received(:call).with(event: event_name, webhook_payload_body: webhook_payload_body)
      end
    end

    describe 'when webhooks are enabled' do
      before { Spree::Webhooks.disabled = false }

      describe 'when not using #disable_webhooks' do
        it 'emits the event' do
          expect do
            variant.discontinue!
          end.to emit_webhook_event(event_name, variant)
        end
      end

      describe 'when using #disable_webhooks' do
        it 'does not emit the event' do
          described_class.disable_webhooks { variant.discontinue! }
          expect(queue_requests).not_to have_received(:call).with(event: event_name, webhook_payload_body: webhook_payload_body)
        end
      end
    end
  end
end
