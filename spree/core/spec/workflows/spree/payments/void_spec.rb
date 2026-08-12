require 'spec_helper'

RSpec.describe Spree::Payments::Void do
  let(:payment) { create(:payment, state: 'pending', amount: 45.75) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'voiding' do
    it 'voids the payment at the gateway' do
      expect(payment).to receive(:void_transaction!).and_return(true)

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'is a no-op for an already-void payment' do
      voided = create(:payment, state: 'void')
      expect(voided).not_to receive(:void_transaction!)

      expect(described_class.call(payment: voided)).to be_success
    end

    it 'fails without calling the gateway when the payment cannot be voided' do
      failed = create(:payment, state: 'failed')
      expect(failed).not_to receive(:void_transaction!)

      result = described_class.call(payment: failed)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_voidable)
    end

    it 'surfaces a gateway error as a failure result' do
      allow(payment).to receive(:void_transaction!).and_raise(Spree::Core::GatewayError, 'cannot void')

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('cannot void')
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the void before the gateway is called' do
      expect(payment).not_to receive(:void_transaction!)
      Spree.hooks.register('payments.void.validate') { |flow| flow.reject!('under review') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('under review')
    end

    it 'runs after_void once the gateway call succeeds' do
      allow(payment).to receive(:void_transaction!).and_return(true)

      voided = false
      Spree.hooks.register('payments.void.after_void') { |_flow| voided = true }

      described_class.call(payment: payment)

      expect(voided).to be(true)
    end
  end
end
