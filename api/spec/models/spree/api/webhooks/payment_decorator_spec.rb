require 'spec_helper'

describe Spree::Payment do
  let(:payment) { create(:payment) }

  describe '#void' do
    let(:body) { Spree::Api::V2::Platform::PaymentSerializer.new(payment).serializable_hash.to_json }
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

    shared_examples 'queues a webhook request' do
      before do
        ENV['DISABLE_SPREE_WEBHOOKS'] = nil
        # Avoid creating a new state change after transitioning as is defined in the model
        # because after_void queues the HTTP request before finishing the transition, hence
        # the total state changes that are sent in the body is one less.
        allow(payment).to receive_message_chain(:state_changes, :create!)
        allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
        allow(queue_requests).to receive(:call).with(any_args)
      end

      after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

      it 'executes QueueRequests.call with a payment.voided event and {} body after invoking void' do
        payment.void
        expect(queue_requests).to have_received(:call).with(event: 'payment.voided', body: body).once
      end
    end

    context 'when transitioning from pending to void' do
      before { payment.pend }

      include_examples 'queues a webhook request'
    end

    context 'when transitioning from processing to void' do
      before { payment.started_processing }

      include_examples 'queues a webhook request'
    end

    context 'when transitioning from completed to void' do
      before { payment.complete }

      include_examples 'queues a webhook request'
    end

    context 'when transitioning from checkout to void' do
      include_examples 'queues a webhook request'
    end
  end
end
