require 'spec_helper'

RSpec.describe Spree::Payments::Process do
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
                     status: 'checkout', amount: 45.75, response_code: nil)
  end
  let(:success_response) do
    Spree::PaymentResponse.new(true, nil, {}, authorization: '123')
  end

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'choosing the verb' do
    it 'authorizes when the method does not capture at checkout' do
      allow(gateway).to receive(:capture_at_checkout?).and_return(false)
      expect(gateway).to receive(:authorize).and_return(success_response)

      expect(described_class.call(payment: payment)).to be_success
      expect(payment.reload).to be_pending
      expect(payment.capture_events.count).to eq(0)
    end

    it 'purchases when the method captures at checkout, recording the capture' do
      allow(gateway).to receive(:capture_at_checkout?).and_return(true)
      expect(gateway).to receive(:purchase).and_return(success_response)

      expect(described_class.call(payment: payment)).to be_success
      expect(payment.reload).to be_completed
      expect(payment.capture_events.sum(:amount)).to eq(45.75)
    end

    it 'lets the caller force a verb over the capture timing' do
      allow(gateway).to receive(:capture_at_checkout?).and_return(true)
      expect(gateway).to receive(:authorize).and_return(success_response)
      expect(gateway).not_to receive(:purchase)

      described_class.call(payment: payment, action: :authorize)

      expect(payment.reload).to be_pending
    end
  end

  describe 'preconditions' do
    it 'is a no-op for a payment already in flight' do
      payment.update_column(:status, 'processing')
      expect(gateway).not_to receive(:authorize)

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'fails when a source-required method has no source' do
      payment.source = nil
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq(Spree.t(:payment_processing_failed))
    end

    it 'invalidates the payment when the card brand is not supported' do
      allow(gateway).to receive(:supports?).and_return(false)
      allow(payment).to receive(:token_based?).and_return(false)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(payment.reload.status).to eq('invalid')
    end
  end

  describe 'racing a concurrent settlement' do
    it 'reports success without the gateway when the webhook settled it first' do
      Spree::Payment.find(payment.id).update_columns(status: 'completed')
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment) # stale: still reads checkout

      expect(result).to be_success
      expect(payment.reload).to be_completed
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto before the gateway is called' do
      expect(gateway).not_to receive(:authorize)
      Spree.hooks.register('payments.process.validate') { |flow| flow.reject!('review first') }

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('review first')
    end
  end
end
