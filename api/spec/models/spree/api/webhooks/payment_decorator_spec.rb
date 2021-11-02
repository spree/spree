require 'spec_helper'

describe Spree::Payment do
  let(:payment) { create(:payment) }
  let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

  before do
    ENV['DISABLE_SPREE_WEBHOOKS'] = nil
    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)
  end

  after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

  describe '#void' do
    let(:body) { Spree::Api::V2::Platform::PaymentSerializer.new(payment).serializable_hash.to_json }

    shared_examples 'emits payment.voided' do
      before do
        # Avoid creating a new state change after transitioning as is defined in the model
        # because after_void queues the HTTP request before finishing the transition, hence
        # the total state changes that are sent in the body is one less.
        allow(payment).to receive_message_chain(:state_changes, :create!)
      end

      it do
        payment.void
        expect(queue_requests).to have_received(:call).with(event: 'payment.voided', body: body).once
      end
    end

    context 'pending -> void' do
      before { payment.pend }

      include_examples 'emits payment.voided'
    end

    context 'processing -> void' do
      before { payment.started_processing }

      include_examples 'emits payment.voided'
    end

    context 'completed -> void' do
      before { payment.complete }

      include_examples 'emits payment.voided'
    end

    context 'checkout -> void' do
      include_examples 'emits payment.voided'
    end
  end

  describe 'order.paid' do
    let(:body) { Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json }
    let(:order) { payment.order }
    let!(:another_payment) { create(:payment, order: order) }

    context 'order.paid? == true' do
      shared_examples 'emits order.paid' do
        it { expect(queue_requests).to have_received(:call).with(event: 'order.paid', body: body).once }
      end

      context 'processing -> complete' do
        before do
          # order.updated_at doesn't coincide without timecop freezing
          Timecop.freeze do
            payment.started_processing
            payment.complete
            another_payment.started_processing
            another_payment.complete
          end
        end

        include_examples 'emits order.paid'
      end

      context 'pending -> complete' do
        before do
          Timecop.freeze do
            payment.pend
            payment.complete
            another_payment.pend
            another_payment.complete
          end
        end

        include_examples 'emits order.paid'
      end

      context 'checkout -> complete' do
        before do
          Timecop.freeze do
            payment.complete
            another_payment.complete
          end
        end

        include_examples 'emits order.paid'
      end
    end

    context 'order.paid? == false' do
      shared_examples 'does not emit order.paid' do
        it { expect(queue_requests).not_to have_received(:call).with(event: 'order.paid', body: body) }
      end

      before do
        allow(payment).to receive(:order).and_return(order)
        allow(order).to receive(:paid?).and_return(false)
      end

      context 'processing -> complete' do
        before do
          Timecop.freeze do
            payment.started_processing
            payment.complete
          end
        end

        include_examples 'does not emit order.paid'
      end

      context 'pending -> complete' do
        before do
          Timecop.freeze do
            payment.pend
            payment.complete
          end
        end

        include_examples 'does not emit order.paid'
      end

      context 'checkout -> complete' do
        before { Timecop.freeze { payment.complete } }

        include_examples 'does not emit order.paid'
      end
    end
  end
end
