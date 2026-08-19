require 'spec_helper'

RSpec.describe Spree::Payments::Capture do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 45.75) }
  let(:gateway) do
    gateway = store.payment_methods.create!(type: 'Spree::Gateway::Bogus', active: true)
    allow(gateway).to receive_messages(source_required: true)
    gateway
  end
  let(:card) { create(:credit_card) }
  let(:payment) do
    create(:payment, order: order, payment_method: gateway, source: card,
                     status: 'pending', amount: 45.75, response_code: '123')
  end
  let(:success_response) do
    Spree::PaymentResponse.new(true, nil, {}, authorization: '123')
  end
  let(:failed_response) { Spree::PaymentResponse.new(false, 'card declined') }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'capturing' do
    it 'captures at the gateway, records the capture event and publishes' do
      expect(gateway).to receive(:capture).with(4575, '123', anything).and_return(success_response)
      expect(payment).to receive(:publish_event).with('payment.completed')
      expect(payment).to receive(:publish_event).with('payment.captured')

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.capture_events.sum(:amount)).to eq(45.75)
    end

    it 'splits a partial capture into a pending remainder and re-authorizes it' do
      expect(gateway).to receive(:capture).with(1000, '123', anything).and_return(success_response)
      expect(gateway).to receive(:authorize)
        .and_return(Spree::PaymentResponse.new(true, nil, {}, authorization: '456'))

      result = described_class.call(payment: payment, amount: 1000)

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.amount).to eq(10.00)

      remainder = order.payments.pending.last
      expect(remainder.amount).to eq(35.75)
    end

    it 'is a no-op for an already-captured payment' do
      completed = create(:payment, payment_method: gateway, source: card, status: 'completed')
      expect(gateway).not_to receive(:capture)

      expect(described_class.call(payment: completed)).to be_success
    end

    it 'retries a failed capture — a failure can be a transient gateway outage' do
      payment.update_column(:status, 'failed')
      expect(gateway).to receive(:capture).with(4575, '123', anything).and_return(success_response)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.capture_events.sum(:amount)).to eq(45.75)
    end

    it 'fails without calling the gateway when the payment cannot be captured' do
      voided = create(:payment, payment_method: gateway, source: card, status: 'void')
      expect(gateway).not_to receive(:capture)

      result = described_class.call(payment: voided)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_capturable)
    end

    it 'records the failure and surfaces a gateway decline as a failure result' do
      allow(gateway).to receive(:capture).and_return(failed_response)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('card declined')
      expect(payment.reload).to be_failed
      expect(payment.capture_events.count).to eq(0)
    end
  end

  describe 'racing a concurrent settlement' do
    # The stale-instance race: the webhook settles the payment while an
    # admin's already-loaded copy still reads pending. The claim must
    # refuse, and the capture must succeed as a no-op — no gateway call,
    # no second capture event, no status regression.
    it 'reports success without touching the settled payment or the gateway' do
      Spree::Payment.find(payment.id).tap do |settled|
        settled.update_columns(status: 'completed')
        settled.capture_events.create!(amount: 45.75)
      end
      expect(gateway).not_to receive(:capture)

      result = described_class.call(payment: payment) # stale: still reads pending

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.capture_events.count).to eq(1)
    end

    it 'fails without calling the gateway when the payment died concurrently' do
      Spree::Payment.find(payment.id).update_columns(status: 'void')
      expect(gateway).not_to receive(:capture)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(payment.reload).to be_void
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the capture before the gateway is called' do
      expect(gateway).not_to receive(:capture)
      Spree.hooks.register('payments.capture.validate') { |flow| flow.reject!('on fraud hold') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('on fraud hold')
    end

    it 'runs after_capture once the gateway call succeeds' do
      allow(gateway).to receive(:capture).and_return(success_response)

      captured = false
      Spree.hooks.register('payments.capture.after_capture') { |_flow| captured = true }

      described_class.call(payment: payment)

      expect(captured).to be(true)
    end
  end

  it 'calls the gateway outside any transaction the workflow opened' do
    open_transactions = nil
    allow(gateway).to receive(:capture) do
      open_transactions = ApplicationRecord.connection.open_transactions
      success_response
    end

    baseline = ApplicationRecord.connection.open_transactions
    described_class.call(payment: payment)

    expect(open_transactions).to eq(baseline)
  end
end
