require 'spec_helper'

RSpec.describe Spree::Payments::Refund do
  let(:payment) { create(:payment, state: 'completed', amount: 45.75) }

  before do
    Spree.hooks.clear!
    # Spree::Refund performs the gateway credit in an after_create callback.
    allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
  end

  after { Spree.hooks.clear! }

  describe 'refunding' do
    it 'creates a refund for the full creditable balance by default' do
      creditable = payment.credit_allowed

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result.value).to be_a(Spree::Refund)
      expect(result.value.amount).to eq(creditable)
    end

    it 'refunds a partial amount' do
      result = described_class.call(payment: payment, amount: 10)

      expect(result.value.amount).to eq(10)
    end

    it 'refuses to refund a payment that was never captured' do
      pending_payment = create(:payment, state: 'pending')

      result = described_class.call(payment: pending_payment)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_refundable)
      expect(pending_payment.refunds).to be_empty
    end

    it 'refuses an amount above the creditable balance' do
      result = described_class.call(payment: payment, amount: payment.amount + 10)

      expect(result).to be_failure
      expect(result.error.value).to eq(:refund_amount_exceeds_balance)
      expect(payment.refunds).to be_empty
    end

    it 'refuses a non-positive amount' do
      expect(described_class.call(payment: payment, amount: 0)).to be_failure
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the refund before the record is created' do
      Spree.hooks.register('payments.refund.validate') { |flow| flow.reject!('refunds disabled') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('refunds disabled')
      expect(payment.refunds).to be_empty
    end

    it 'exposes the created refund to after_refund' do
      seen = nil
      Spree.hooks.register('payments.refund.after_refund') { |flow| seen = flow.refund }

      described_class.call(payment: payment, amount: 5)

      expect(seen).to be_a(Spree::Refund)
      expect(seen.amount).to eq(5)
    end
  end
end
