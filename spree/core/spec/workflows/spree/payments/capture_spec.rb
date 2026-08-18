require 'spec_helper'

RSpec.describe Spree::Payments::Capture do
  let(:payment) { create(:payment, status: 'pending', amount: 45.75) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'capturing' do
    it 'captures the payment at the gateway and publishes the event' do
      expect(payment).to receive(:capture!).with(nil).and_return(true)
      expect(payment).to receive(:publish_event).with('payment.captured')

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'passes a partial amount through to the gateway' do
      expect(payment).to receive(:capture!).with(1000).and_return(true)
      allow(payment).to receive(:publish_event)

      described_class.call(payment: payment, amount: 1000)
    end

    it 'is a no-op for an already-captured payment' do
      completed = create(:payment, status: 'completed')
      expect(completed).not_to receive(:capture!)

      expect(described_class.call(payment: completed)).to be_success
    end

    it 'fails without calling the gateway when the payment cannot be captured' do
      voided = create(:payment, status: 'void')
      expect(voided).not_to receive(:capture!)

      result = described_class.call(payment: voided)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_capturable)
    end

    it 'surfaces a gateway error as a failure result' do
      allow(payment).to receive(:capture!).and_raise(Spree::Core::GatewayError, 'card declined')

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('card declined')
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the capture before the gateway is called' do
      expect(payment).not_to receive(:capture!)
      Spree.hooks.register('payments.capture.validate') { |flow| flow.reject!('on fraud hold') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('on fraud hold')
    end

    it 'runs after_capture once the gateway call succeeds' do
      allow(payment).to receive(:capture!).and_return(true)
      allow(payment).to receive(:publish_event)

      captured = false
      Spree.hooks.register('payments.capture.after_capture') { |_flow| captured = true }

      described_class.call(payment: payment)

      expect(captured).to be(true)
    end
  end

  it 'calls the gateway outside any transaction the workflow opened' do
    # The point of the graduation: external_step raises if the gateway call
    # would share a workflow-opened transaction.
    open_transactions = nil
    allow(payment).to receive(:capture!) do
      open_transactions = ApplicationRecord.connection.open_transactions
      true
    end
    allow(payment).to receive(:publish_event)

    baseline = ApplicationRecord.connection.open_transactions
    described_class.call(payment: payment)

    expect(open_transactions).to eq(baseline)
  end
end
