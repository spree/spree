require 'spec_helper'

RSpec.describe Spree::Payments::Void do
  let(:store) { @default_store }
  let(:gateway) do
    gateway = store.payment_methods.create!(type: 'Spree::Gateway::Bogus', active: true)
    allow(gateway).to receive_messages(source_required: true)
    gateway
  end
  let(:card) { create(:credit_card) }
  let(:payment) do
    create(:payment, payment_method: gateway, source: card, status: 'pending',
                     amount: 45.75, response_code: '123')
  end
  let(:success_response) do
    Spree::PaymentResponse.new(true, nil, {}, authorization: '456', avs_result: { code: 'D' })
  end
  let(:failed_response) { Spree::PaymentResponse.new(false, 'cannot void') }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'voiding' do
    it 'voids the payment at the gateway and records the new authorization' do
      expect(gateway).to receive(:void).with('123', card, anything).and_return(success_response)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload).to be_void
      expect(payment.response_code).to eq('456')
    end

    it 'voids without the source when the gateway has no payment profiles' do
      allow(gateway).to receive(:payment_profiles_supported?).and_return(false)
      expect(gateway).to receive(:void).with('123', anything).and_return(success_response)

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'voids without calling the gateway when nothing ever reached it' do
      payment.update_column(:response_code, nil)
      expect(gateway).not_to receive(:void)

      expect(described_class.call(payment: payment)).to be_success
      expect(payment.reload).to be_void
    end

    it 'is a no-op for an already-void payment' do
      voided = create(:payment, payment_method: gateway, source: card, status: 'void')
      expect(gateway).not_to receive(:void)

      expect(described_class.call(payment: voided)).to be_success
    end

    it 'fails without calling the gateway when the payment cannot be voided' do
      failed = create(:payment, payment_method: gateway, source: card, status: 'failed')
      expect(gateway).not_to receive(:void)

      result = described_class.call(payment: failed)

      expect(result).to be_failure
      expect(result.error.value).to eq(:payment_not_voidable)
    end

    it 'surfaces a gateway failure as a failure result and does not void' do
      allow(gateway).to receive(:void).and_return(failed_response)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq('cannot void')
      expect(payment.reload).not_to be_void
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the void before the gateway is called' do
      expect(gateway).not_to receive(:void)
      Spree.hooks.register('payments.void.validate') { |flow| flow.reject!('under review') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('under review')
    end

    it 'runs after_void once the gateway call succeeds' do
      allow(gateway).to receive(:void).and_return(success_response)

      voided = false
      Spree.hooks.register('payments.void.after_void') { |_flow| voided = true }

      described_class.call(payment: payment)

      expect(voided).to be(true)
    end
  end
end
