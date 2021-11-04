require 'spec_helper'

describe Spree::Payment do
  let(:body) { Spree::Api::V2::Platform::PaymentSerializer.new(payment).serializable_hash.to_json }
  let(:payment) { create(:payment) }

  before { allow(payment).to receive_message_chain(:state_changes, :create!) }

  describe 'payment.paid' do
    context 'processing -> completed' do
      before { payment.started_processing }

      it { expect { payment.complete }.to emit_webhook_event('payment.paid') }
    end

    context 'pending -> completed' do
      before { payment.pend }

      it { expect { payment.complete }.to emit_webhook_event('payment.paid') }
    end

    context 'checkout -> completed' do
      it { expect { payment.complete }.to emit_webhook_event('payment.paid') }
    end
  end

  describe 'payment.voided' do
    context 'pending -> void' do
      before { payment.pend }

      it { expect { payment.void }.to emit_webhook_event('payment.voided') }
    end

    context 'processing -> void' do
      before { payment.started_processing }

      it { expect { payment.void }.to emit_webhook_event('payment.voided') }
    end

    context 'completed -> void' do
      before { payment.complete }

      it { expect { payment.void }.to emit_webhook_event('payment.voided') }
    end

    context 'checkout -> void' do
      it { expect { payment.void }.to emit_webhook_event('payment.voided') }
    end
  end

  describe 'order.paid' do
    subject { Timecop.freeze { another_payment.complete } }

    let(:body) { Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json }
    let(:order) { payment.order }
    let!(:another_payment) { create(:payment, order: order) }

    context 'order.paid? == true' do
      context 'processing -> complete' do
        before do
          payment.started_processing
          payment.complete
          another_payment.started_processing
        end

        it { expect { subject }.to emit_webhook_event('order.paid') }
      end

      context 'pending -> complete' do
        before do
          payment.pend
          payment.complete
          another_payment.pend
        end

        it { expect { subject }.to emit_webhook_event('order.paid') }
      end

      context 'checkout -> complete' do
        before { payment.complete }

        it { expect { subject }.to emit_webhook_event('order.paid') }
      end
    end

    context 'order.paid? == false' do
      before do
        allow(payment).to receive(:order).and_return(order)
        allow(order).to receive(:paid?).and_return(false)
      end

      context 'processing -> complete' do
        before { payment.started_processing }

        it { expect { subject }.not_to emit_webhook_event('order.paid') }
      end

      context 'pending -> complete' do
        before { payment.pend }

        it { expect { subject }.not_to emit_webhook_event('order.paid') }
      end

      context 'checkout -> complete' do
        it { expect { subject }.not_to emit_webhook_event('order.paid') }
      end
    end
  end
end
