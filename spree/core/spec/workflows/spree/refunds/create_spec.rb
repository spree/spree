require 'spec_helper'

RSpec.describe Spree::Refunds::Create do
  let(:payment) { create(:payment, status: 'completed', amount: 45.75) }

  before do
    Spree.hooks.clear!
    allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
  end

  after { Spree.hooks.clear! }

  describe 'refunding' do
    it 'creates a refund for the full creditable balance and credits it at the gateway' do
      creditable = payment.credit_allowed
      expect_any_instance_of(Spree::Refund).to receive(:perform!)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(result.value).to be_a(Spree::Refund)
      expect(result.value.amount).to eq(creditable)
    end

    it 'refunds a partial amount' do
      result = described_class.call(payment: payment, amount: 10)

      expect(result.value.amount).to eq(10)
    end

    it 'records the originator' do
      originator = create(:return)

      result = described_class.call(payment: payment, originator: originator)

      expect(result.value.originator).to eq(originator)
    end

    it 'refuses to refund a payment that was never captured' do
      pending_payment = create(:payment, status: 'pending')

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

    it 'creates the refund row under the payment row lock' do
      expect(payment).to receive(:with_lock).and_call_original

      described_class.call(payment: payment)
    end

    it 'destroys the uncredited refund when the gateway declines' do
      allow_any_instance_of(Spree::Refund).to receive(:perform!).
        and_raise(Spree::Core::GatewayError, 'declined')

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('declined')
      expect(payment.refunds.reload).to be_empty
    end

    it 'keeps a credited refund even when a later step fails' do
      allow_any_instance_of(Spree::Refund).to receive(:perform!) do |refund|
        refund.update_columns(transaction_id: 'txn_123')
      end
      Spree.hooks.register('refunds.create.after_refund') { |flow| flow.reject!('observer exploded') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(payment.refunds.reload.count).to eq(1)
      expect(payment.refunds.first.transaction_id).to eq('txn_123')
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the refund before the record is created' do
      Spree.hooks.register('refunds.create.validate') { |flow| flow.reject!('refunds disabled') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('refunds disabled')
      expect(payment.refunds).to be_empty
    end

    it 'exposes the created refund to after_refund' do
      seen = nil
      Spree.hooks.register('refunds.create.after_refund') { |flow| seen = flow.refund }

      described_class.call(payment: payment, amount: 5)

      expect(seen).to be_a(Spree::Refund)
      expect(seen.amount).to eq(5)
    end
  end
end
