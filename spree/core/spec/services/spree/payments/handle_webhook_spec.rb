require 'spec_helper'

RSpec.describe Spree::Payments::HandleWebhook do
  subject { described_class }

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: order.total) }

  before do
    order.update_column(:state, 'payment')
    order.shipments.each { |s| s.update_column(:state, 'ready') }
  end

  describe '#call' do
    context 'with :captured action' do
      it 'creates a payment record' do
        expect {
          subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)
        }.to change { order.payments.count }.by(1)
      end

      it 'completes the payment session' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(payment_session.reload.status).to eq('completed')
      end

      it 'completes the order' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(order.reload.state).to eq('complete')
      end

      it 'returns success' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(result).to be_success
      end
    end

    context 'with :authorized action' do
      it 'creates a payment record and completes the order' do
        result = subject.call(payment_method: payment_method, action: :authorized, payment_session: payment_session)

        expect(result).to be_success
        expect(payment_session.reload.status).to eq('completed')
        expect(order.reload.payments.count).to eq(1)
      end
    end

    context 'with :failed action' do
      it 'fails the payment session' do
        result = subject.call(payment_method: payment_method, action: :failed, payment_session: payment_session)

        expect(result).to be_success
        expect(payment_session.reload.status).to eq('failed')
      end

      it 'does not create a payment' do
        expect {
          subject.call(payment_method: payment_method, action: :failed, payment_session: payment_session)
        }.not_to change { order.payments.count }
      end

      it 'does not complete the order' do
        subject.call(payment_method: payment_method, action: :failed, payment_session: payment_session)

        expect(order.reload.state).not_to eq('complete')
      end
    end

    context 'with :canceled action' do
      it 'cancels the payment session' do
        result = subject.call(payment_method: payment_method, action: :canceled, payment_session: payment_session)

        expect(result).to be_success
        expect(payment_session.reload.status).to eq('canceled')
      end
    end

    context 'when payment_session is nil' do
      it 'returns success without processing' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: nil)

        expect(result).to be_success
      end
    end

    context 'when order is already completed' do
      before do
        order.update_columns(state: 'complete', completed_at: Time.current)
      end

      it 'still creates the payment and completes the session' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(result).to be_success
        expect(payment_session.reload.status).to eq('completed')
        expect(order.payments.count).to eq(1)
      end
    end

    context 'when payment session is already completed' do
      before do
        payment_session.update_column(:status, 'completed')
      end

      it 'does not fail on duplicate webhook' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(result).to be_success
      end
    end
  end
end
