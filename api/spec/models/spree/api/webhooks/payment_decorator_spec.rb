require 'spec_helper'

describe Spree::Payment do
  let(:body) { Spree::Api::V2::Platform::PaymentSerializer.new(payment, serializer_params(event: params)).serializable_hash.to_json }
  let(:payment) { create(:payment) }

  before { allow(payment).to receive_message_chain(:state_changes, :create!) }

  describe 'payment.paid' do
    let(:params) { 'payment.paid' }

    context 'processing -> completed' do
      before { payment.started_processing }

      it { expect { payment.complete }.to emit_webhook_event(params) }
    end

    context 'pending -> completed' do
      before { payment.pend }

      it { expect { payment.complete }.to emit_webhook_event(params) }
    end

    context 'checkout -> completed' do
      it { expect { payment.complete }.to emit_webhook_event(params) }
    end
  end

  describe 'payment.voided' do
    let(:params) { 'payment.voided' }

    context 'pending -> void' do
      before { payment.pend }

      it { expect { payment.void }.to emit_webhook_event(params) }
    end

    context 'processing -> void' do
      before { payment.started_processing }

      it { expect { payment.void }.to emit_webhook_event(params) }
    end

    context 'completed -> void' do
      before { payment.complete }

      it { expect { payment.void }.to emit_webhook_event(params) }
    end

    context 'checkout -> void' do
      it { expect { payment.void }.to emit_webhook_event(params) }
    end
  end

  describe 'order.paid' do
    subject { Timecop.freeze { another_payment.complete } }

    let(:params) { 'order.paid' }
    let(:body) { Spree::Api::V2::Platform::OrderSerializer.new(order, serializer_params(event: params)).serializable_hash.to_json }
    let(:order) { payment.order }
    let!(:another_payment) { create(:payment, order: order) }

    context 'order.paid? == true' do
      context 'processing -> complete' do
        before do
          payment.started_processing
          payment.complete
          another_payment.started_processing
        end

        it { expect { subject }.to emit_webhook_event(params) }
      end

      context 'pending -> complete' do
        before do
          payment.pend
          payment.complete
          another_payment.pend
        end

        let(:params) { 'order.paid' }

        it { expect { subject }.to emit_webhook_event(params) }
      end

      context 'checkout -> complete' do
        before { payment.complete }

        it { expect { subject }.to emit_webhook_event(params) }
      end
    end

    context 'order.paid? == false' do
      before do
        allow(payment).to receive(:order).and_return(order)
        allow(order).to receive(:paid?).and_return(false)
      end

      context 'processing -> complete' do
        before { payment.started_processing }

        it { expect { subject }.not_to emit_webhook_event(params) }
      end

      context 'pending -> complete' do
        before { payment.pend }

        it { expect { subject }.not_to emit_webhook_event(params) }
      end

      context 'checkout -> complete' do
        it { expect { subject }.not_to emit_webhook_event(params) }
      end
    end
  end
end
