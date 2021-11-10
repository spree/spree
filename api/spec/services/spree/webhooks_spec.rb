require 'spec_helper'

describe Spree::Webhooks do
  describe '#disable_webhooks' do
    let(:variant) { create(:variant) }
    let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

    before do
      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

    describe 'when block is not passed' do
      it 'raises an error' do
        expect { described_class.disable_webhooks }.to raise_error(NoMethodError)
      end
    end

    describe 'the value of DISABLE_SPREE_WEBHOOKS environment variable' do
      before { ENV['DISABLE_SPREE_WEBHOOKS'] = 'some_value' }

      describe 'when an error is not raised' do
        it 'sets it to the original value' do
          described_class.disable_webhooks { variant.discontinue! }
          expect(ENV['DISABLE_SPREE_WEBHOOKS']).to eq('some_value')
        end
      end

      describe 'when an error is raised' do
        it 'sets it to the original value' do
          begin
            described_class.disable_webhooks { raise StandardError }
          rescue StandardError
          end
          expect(ENV['DISABLE_SPREE_WEBHOOKS']).to eq('some_value')
        end
      end
    end

    describe 'when webhooks are already disabled' do
      before { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

      it 'does not emit the event' do
        described_class.disable_webhooks { variant.discontinue! }
        expect(queue_requests).not_to have_received(:call).with(event: 'variant.discontinued', body: body)
      end
    end

    describe 'when webhooks are enabled' do
      before { ENV['DISABLE_SPREE_WEBHOOKS'] = nil }

      describe 'when not using #disable_webhooks' do
        it 'emits the event' do
          variant.discontinue!
          expect(queue_requests).to have_received(:call).with(event: 'variant.discontinued', body: body).once
        end
      end

      describe 'when using #disable_webhooks' do
        it 'does not emit the event' do
          described_class.disable_webhooks { variant.discontinue! }
          expect(queue_requests).not_to have_received(:call).with(event: 'variant.discontinued', body: body)
        end
      end
    end
  end
end
