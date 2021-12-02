require 'spec_helper'

describe Spree::Api::Webhooks::PaymentDecorator do
  let(:webhook_payload_body) { Spree::Api::V2::Platform::PaymentSerializer.new(payment).serializable_hash }
  let(:payment) { create(:payment) }

  before { allow(payment).to receive_message_chain(:state_changes, :create!) }

  describe 'payment.paid' do
    let(:event_name) { 'payment.paid' }

    context 'processing -> completed' do
      before { payment.started_processing }

      it { expect { payment.complete }.to emit_webhook_event(event_name) }
    end

    context 'pending -> completed' do
      before { payment.pend }

      it { expect { payment.complete }.to emit_webhook_event(event_name) }
    end

    context 'checkout -> completed' do
      it { expect { payment.complete }.to emit_webhook_event(event_name) }
    end
  end

  describe 'payment.voided' do
    let(:event_name) { 'payment.voided' }

    context 'pending -> void' do
      before { payment.pend }

      it { expect { payment.void }.to emit_webhook_event(event_name) }
    end

    context 'processing -> void' do
      before { payment.started_processing }

      it { expect { payment.void }.to emit_webhook_event(event_name) }
    end

    context 'completed -> void' do
      before { payment.complete }

      it { expect { payment.void }.to emit_webhook_event(event_name) }
    end

    context 'checkout -> void' do
      it { expect { payment.void }.to emit_webhook_event(event_name) }
    end
  end

  describe 'order.paid' do
    subject { Timecop.freeze { another_payment.complete } }

    let(:webhook_payload_body) { Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash }
    let(:order) { payment.order }
    let(:event_name) { 'order.paid' }
    let!(:another_payment) { create(:payment, order: order) }

    context 'order.paid? == true' do
      context 'processing -> complete' do
        before do
          payment.started_processing
          payment.complete
          another_payment.started_processing
        end

        it { expect { subject }.to emit_webhook_event(event_name) }
      end

      context 'pending -> complete' do
        before do
          payment.pend
          payment.complete
          another_payment.pend
        end

        it { expect { subject }.to emit_webhook_event(event_name) }
      end

      context 'checkout -> complete' do
        before { payment.complete }

        it { expect { subject }.to emit_webhook_event(event_name) }
      end
    end

    context 'order.paid? == false' do
      before do
        allow(payment).to receive(:order).and_return(order)
        allow(order).to receive(:paid?).and_return(false)
      end

      context 'processing -> complete' do
        before { payment.started_processing }

        it { expect { subject }.not_to emit_webhook_event(event_name) }
      end

      context 'pending -> complete' do
        before { payment.pend }

        it { expect { subject }.not_to emit_webhook_event(event_name) }
      end

      context 'checkout -> complete' do
        it { expect { subject }.not_to emit_webhook_event(event_name) }
      end
    end
  end
end
