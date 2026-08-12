require 'spec_helper'

RSpec.describe Spree::Payments::HandleWebhook do
  subject { described_class }

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:payment_method) { create(:bogus_payment_method) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: order.total) }

  before do
    order.shipments.each { |s| s.update_column(:state, 'ready') }
  end

  describe '#call' do
    # Manual capture and delayed-notification banks complete the session while
    # the payment is only authorized; the capture webhook that follows must
    # still settle it.
    context 'when a capture follows an authorization on the same session' do
      before do
        subject.call(payment_method: payment_method, action: :authorized, payment_session: payment_session)
      end

      it 'leaves the session completed with the payment pending' do
        expect(payment_session.reload).to be_completed
        expect(order.payments.last).to be_pending
      end

      it 'completes the payment when the capture arrives' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session.reload)

        payment = order.payments.reload.last
        expect(payment).to be_completed
        expect(payment.capture_events.sum(:amount)).to eq(payment.amount)
      end

      it 'does not record a second capture on a replayed capture webhook' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session.reload)

        expect {
          subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session.reload)
        }.not_to change { order.payments.reload.last.capture_events.count }
      end
    end

    context 'with :captured action' do
      it 'fetches provider data before taking the order lock' do
        expect(payment_session).to receive(:prepare_for_settlement!).and_call_original

        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)
      end

      it 'creates a payment record' do
        expect {
          subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)
        }.to change { order.payments.count }.by(1)
      end

      it 'completes the payment session' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(payment_session.reload.status).to eq('completed')
      end

      it 'completes the payment' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(order.reload.payments.first.state).to eq('completed')
      end

      it 'completes the order with payment_state=paid' do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        order.reload
        expect(order.completed_at).to be_present
        expect(order.payment_state).to eq('paid')
      end

      it 'returns success' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(result).to be_success
      end
    end

    context 'with :authorized action and a manual-capture payment method' do
      let(:payment_method) { create(:bogus_payment_method, capture_method: 'manual') }

      it 'creates a payment record in pending state' do
        result = subject.call(payment_method: payment_method, action: :authorized, payment_session: payment_session)

        expect(result).to be_success
        expect(order.reload.payments.count).to eq(1)
        expect(order.payments.first.state).to eq('pending')
      end

      it 'completes the payment session' do
        subject.call(payment_method: payment_method, action: :authorized, payment_session: payment_session)

        expect(payment_session.reload.status).to eq('completed')
      end

      it 'completes the order but leaves payment_state as balance_due (funds on hold, not captured)' do
        subject.call(payment_method: payment_method, action: :authorized, payment_session: payment_session)

        order.reload
        expect(order.completed_at).to be_present
        # 6.0 payment_status domain: an uncaptured hold reports 'authorized'
        expect(order.payment_state).to eq('authorized')
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

        expect(order.reload.completed_at).to be_nil
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
        order.update_columns(status: 'placed', completed_at: Time.current)
      end

      it 'still creates the payment and completes the session' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)

        expect(result).to be_success
        expect(payment_session.reload.status).to eq('completed')
        expect(order.payments.count).to eq(1)
      end
    end

    # Replay protection keys off the payment, not the session: an authorized
    # session is completed while its payment is still pending, and the capture
    # webhook that follows must be able to settle it.
    context 'when the payment is already completed' do
      before do
        subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)
      end

      it 'does not fail on duplicate webhook' do
        result = subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session.reload)

        expect(result).to be_success
      end

      it 'does not create a duplicate payment' do
        expect {
          subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session.reload)
        }.not_to change { order.payments.reload.count }
      end
    end

    context 'when the session was completed without a payment' do
      before do
        payment_session.update_column(:status, 'completed')
      end

      # The session-status guard used to strand these — settlement never ran.
      it 'still settles the payment' do
        expect {
          subject.call(payment_method: payment_method, action: :captured, payment_session: payment_session)
        }.to change { order.payments.reload.count }.by(1)
      end
    end
  end
end
