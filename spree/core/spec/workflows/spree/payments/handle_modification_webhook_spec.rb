require 'spec_helper'

RSpec.describe Spree::Payments::HandleModificationWebhook do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:payment_method) { create(:credit_card_payment_method, store: store, preferred_requested_mode: true) }
  let(:payment) do
    create(:payment, order: order, payment_method: payment_method, amount: order.total, status: 'pending', response_code: 'BGS-PAY')
  end

  before do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)
  end

  def outcome(action, record, metadata = {})
    described_class.call(payment_method: payment_method, action: action, record: record, metadata: metadata)
  end

  def published?(name)
    have_received(:publish).with(name, anything, anything)
  end

  def request_capture(amount = nil)
    Spree::Payments::Capture.call(payment: payment, amount: amount)
    payment.capture_events.sole
  end

  describe 'a capture' do
    let!(:capture_event) { request_capture }

    it 'completes the capture event and the payment when it succeeds' do
      outcome(:capture_succeeded, capture_event)

      expect(capture_event.reload).to be_completed
      expect(payment.reload).to be_completed
      expect(payment.captured_amount).to eq(order.total)
      expect(Spree::Events).to published?('payment.captured')
    end

    it 'completes a session payment that carries no source' do
      payment.update_columns(source_id: nil, source_type: nil)

      outcome(:capture_succeeded, capture_event)

      expect(payment.reload).to be_completed
    end

    it 'changes nothing on a repeat delivery' do
      outcome(:capture_succeeded, capture_event)

      expect { outcome(:capture_succeeded, capture_event) }.not_to(change { [payment.reload.updated_at, capture_event.reload.updated_at] })
    end

    it 'fails the capture event and the payment, recording the reason, when it fails' do
      outcome(:capture_failed, capture_event, 'reason' => 'Authorisation expired')

      expect(capture_event.reload).to be_failed
      expect(payment.reload).to be_failed
      expect(payment.gateway_processing_error_messages).to include('Authorisation expired')
      expect(Spree::Events).to published?('payment.capture_failed')
    end

    it 'takes the money back on a failure after success' do
      outcome(:capture_succeeded, capture_event)
      # What the order status subscriber does on payment.completed, stubbed out here.
      order.refresh_payment_total!
      expect(order.reload.payment_total).to eq(order.total)

      outcome(:capture_failed, capture_event.reload, 'reason' => 'Chargeback')

      expect(capture_event.reload).to be_failed
      expect(payment.reload).to be_failed
      expect(order.reload.payment_total).to eq(0)
      expect(order.payment_status).not_to eq('paid')
    end

    it 'ignores a failure for a capture that already failed' do
      outcome(:capture_failed, capture_event)

      expect { outcome(:capture_failed, capture_event) }.not_to(change { payment.reload.gateway_processing_error_messages })
    end
  end

  describe 'a partial capture' do
    let!(:capture_event) { request_capture(BigDecimal('10')) }

    before do
      allow_any_instance_of(Spree::Gateway::Bogus).to receive(:authorize).
        and_return(Spree::PaymentResponse.new(true, 'ok', {}, authorization: 'BGS-REMAINDER'))
    end

    it 'reports a remainder the gateway cannot authorize without failing the outcome' do
      allow_any_instance_of(Spree::Gateway::Bogus).to receive(:authorize).
        and_return(Spree::PaymentResponse.new(false, 'no session'))
      allow(Rails.error).to receive(:report)

      expect(outcome(:capture_succeeded, capture_event)).to be_success
      expect(payment.reload).to be_completed
      expect(Rails.error).to have_received(:report).with(kind_of(Spree::Core::GatewayError), hash_including(handled: true))
    end

    it 'splits the remainder and authorizes it once the capture succeeds' do
      outcome(:capture_succeeded, capture_event)

      expect(payment.reload).to have_attributes(status: 'completed', amount: 10)
      remainder = order.payments.where.not(id: payment.id).sole
      expect(remainder).to have_attributes(amount: order.total - 10, status: 'pending')
    end
  end

  describe 'a void' do
    before { Spree::Payments::Void.call(payment: payment) }

    it 'voids the payment when it succeeds' do
      outcome(:void_succeeded, payment.reload)

      expect(payment.reload).to be_void
    end

    it 'changes nothing on a repeat delivery' do
      outcome(:void_succeeded, payment.reload)

      expect { outcome(:void_succeeded, payment.reload) }.not_to(change { payment.reload.updated_at })
    end

    it 'puts a captured payment back to completed when its void fails' do
      payment.update_columns(status: 'requested')
      create(:payment_capture_event, payment: payment, amount: payment.amount)

      outcome(:void_failed, payment.reload)

      expect(payment.reload).to be_completed
    end

    it 'puts the payment back to pending, recording the reason, when it fails' do
      outcome(:void_failed, payment.reload, 'reason' => 'Already captured')

      expect(payment.reload).to be_pending
      expect(payment.gateway_processing_error_messages).to include('Already captured')
      expect(Spree::Events).to published?('payment.void_failed')
    end

    it 'ignores a void outcome for a payment waiting on a capture' do
      waiting = create(:payment, order: order, payment_method: payment_method, status: 'requested')
      create(:payment_capture_event, :requested, payment: waiting)

      outcome(:void_succeeded, waiting)

      expect(waiting.reload).to be_requested
    end
  end

  describe 'a refund' do
    let(:payment) do
      create(:payment, order: order, payment_method: payment_method, amount: order.total, status: 'completed', response_code: 'BGS-PAY')
    end
    let(:refund) { Spree::Refunds::Create.call(payment: payment, amount: 10).value }

    it 'completes the refund and recalculates the order when it succeeds' do
      outcome(:refund_succeeded, refund)

      expect(refund.reload).to be_completed
      expect(order.reload.payment_total).to eq(order.total - 10)
      expect(Spree::Events).to published?('payment.refunded')
    end

    it 'changes nothing on a repeat delivery' do
      outcome(:refund_succeeded, refund)

      expect { outcome(:refund_succeeded, refund) }.not_to(change { refund.reload.updated_at })
    end

    it 'derives the order figures again on a repeat delivery, so a refresh that failed is repaired' do
      refund
      allow_any_instance_of(Spree::Order).to receive(:recalculate_totals!).and_raise(ActiveRecord::StatementInvalid, 'lost connection')
      expect { outcome(:refund_succeeded, refund) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(refund.reload).to be_completed
      expect(order.reload.payment_total).to eq(order.total)

      allow_any_instance_of(Spree::Order).to receive(:recalculate_totals!).and_call_original
      outcome(:refund_succeeded, refund)

      expect(order.reload.payment_total).to eq(order.total - 10)
    end

    it 'fails the refund and releases its balance when it fails' do
      outcome(:refund_failed, refund, 'reason' => 'Account closed')

      expect(refund.reload).to have_attributes(status: 'failed', failure_reason: 'Account closed')
      expect(payment.reload.credit_allowed).to eq(order.total)
      expect(Spree::Events).to published?('refund.failed')
    end

    it 'gives the money back to the order on a failure after success' do
      outcome(:refund_succeeded, refund)
      outcome(:refund_failed, refund.reload, 'reason' => 'Reversed')

      expect(refund.reload).to be_failed
      expect(order.reload.payment_total).to eq(order.total)
    end
  end

  # A mismatch fails the same way on every retry, so it is reported and not
  # retried.
  describe 'guards' do
    before { allow(Rails.error).to receive(:report) }

    it 'reports an outcome naming the wrong kind of record and acts on nothing' do
      payment.update_columns(status: 'requested')

      expect(outcome(:refund_succeeded, payment)).to be_success
      expect(payment.reload).to be_requested
      expect(Rails.error).to have_received(:report).with(kind_of(ArgumentError), hash_including(handled: true))
    end

    it "reports an outcome for another method's payment and acts on nothing" do
      other = create(:payment, order: order, status: 'requested')

      expect(outcome(:void_succeeded, other)).to be_success
      expect(other.reload).to be_requested
      expect(Rails.error).to have_received(:report).with(kind_of(ArgumentError), hash_including(handled: true))
    end
  end
end
