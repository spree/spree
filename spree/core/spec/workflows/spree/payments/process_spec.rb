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
      expect(result.error.value).to eq(I18n.t('spree.payment_processing_failed'))
    end

    it 'invalidates the payment when the card brand is not supported' do
      allow(gateway).to receive(:supports?).and_return(false)
      allow(payment).to receive(:token_based?).and_return(false)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(payment.reload.status).to eq('invalid')
    end
  end

  describe 'an order carrying other live payments' do
    let(:order) { create(:order, store: store, total: BigDecimal('49.99')) }
    let(:payment) do
      create(:payment, order: order, payment_method: gateway, source: card, status: 'checkout', amount: 40, response_code: nil)
    end

    before { allow(gateway).to receive(:capture_at_checkout?).and_return(false) }

    it 'charges only what the others leave owing' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload.amount).to eq(BigDecimal('9.99'))
      expect(payment).to be_pending
    end

    it 'leaves a completed payment\'s amount alone' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      payment.update_columns(status: 'completed')

      described_class.call(payment: payment)

      expect(payment.reload.amount).to eq(40)
    end

    it 'resizes a store-credit payment with a fresh eligibility event for the new amount' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      store_credit_payment = create(:store_credit_payment, order: order, amount: 40, status: 'checkout')

      described_class.call(payment: store_credit_payment)

      expect(store_credit_payment.reload.amount).to eq(BigDecimal('9.99'))
      eligible = store_credit_payment.source.store_credit_events.where(action: Spree::StoreCredit::ELIGIBLE_ACTION)
      expect(eligible.pluck(:amount)).to include(BigDecimal('9.99'))
    end

    it 'leaves the amount of a payment that completed after it was read' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      payment # read while still checkout
      Spree::Payment.find(payment.id).update_columns(status: 'completed')
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment) # stale: still reads checkout

      expect(result).to be_success
      expect(Spree::Payment.find(payment.id).amount).to eq(40)
    end

    it 'limits to what is owed once another payment claimed after the first check' do
      sibling = create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'checkout', amount: 40)
      # The validate hook runs between the early limit and the claim — the
      # window another request's claim can land in.
      Spree.hooks.register('payments.process.validate') { |_flow| sibling.update_columns(status: 'processing') }
      allow(gateway).to receive(:authorize).and_return(success_response)

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload.amount).to eq(BigDecimal('9.99'))
    end

    it 'leaves the amount of a payment another run has already claimed' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      payment # read while still checkout
      Spree::Payment.find(payment.id).update_columns(status: 'processing')
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment) # stale: still reads checkout

      expect(result).to be_success
      expect(Spree::Payment.find(payment.id).amount).to eq(40)
    end

    it 'leaves a payment another run claimed even when no resize is needed' do
      payment # read while still checkout, at 40
      # Another run resized it to what was owed then and claimed it.
      Spree::Payment.find(payment.id).update_columns(status: 'processing', amount: 10)
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment) # stale: still reads checkout at 40, and 49.99 is owed

      expect(result).to be_success
      expect(Spree::Payment.find(payment.id).amount).to eq(10)
    end

    it 'charges the amount the row holds when another run resized it after it was read' do
      payment # read while still checkout, at 40
      # Another run resized it to what was owed then, claimed it and failed at the gateway.
      Spree::Payment.find(payment.id).update_columns(status: 'failed', amount: BigDecimal('9.99'))
      charged = gateway.gateway_amount(BigDecimal('9.99'), payment.currency)
      expect(gateway).to receive(:authorize).with(charged, anything, anything).and_return(success_response)

      result = described_class.call(payment: payment) # stale: still reads checkout at 40, and 49.99 is owed

      expect(result).to be_success
      expect(Spree::Payment.find(payment.id).amount).to eq(BigDecimal('9.99'))
    end

    it 'keeps the unsaved source details when refreshing the payment from its row' do
      payment.source.verification_value = '123'
      allow(gateway).to receive(:authorize) do |_amount, source, _options|
        expect(source.verification_value).to eq('123')
        success_response
      end

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'still fails a payment a hook voided before the claim' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      Spree.hooks.register('payments.process.validate') { |_flow| Spree::Payment.find(payment.id).update_columns(status: 'void') }
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(Spree::Payment.find(payment.id).amount).to eq(40)
    end

    it 'leaves a completed payment on a canceled order as a success' do
      payment.update_columns(status: 'completed')
      order.update_columns(status: 'canceled')
      expect(gateway).not_to receive(:authorize)

      expect(described_class.call(payment: payment)).to be_success
    end

    it 'limits an unsaved payment and saves it with its claim' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'pending', amount: 40)
      unsaved = Spree::Payment.new(order: order, payment_method: gateway, source: card, status: 'checkout', amount: 40)
      allow(gateway).to receive(:authorize).and_return(success_response)

      result = described_class.call(payment: unsaved)

      expect(result).to be_success
      expect(unsaved).to be_persisted
      expect(unsaved.reload.amount).to eq(BigDecimal('9.99'))
    end

    it 'refuses a payment the others already cover' do
      create(:payment, order: order, payment_method: gateway, source: create(:credit_card), status: 'completed', amount: BigDecimal('49.99'))
      expect(gateway).not_to receive(:authorize)

      result = described_class.call(payment: payment)

      expect(result).to be_failure
      expect(result.error.value).to eq(I18n.t('spree.order_payment_already_covered'))
      expect(payment.reload).to be_checkout
    end
  end

  describe 'an order batch where a captured payment was partly refunded' do
    let(:check_method) { create(:check_payment_method, store: store) }
    let(:order) { create(:order_with_line_items, store: store) }

    it 'still charges a payment for what the refund left owing' do
      order.update_columns(status: 'draft', completed_at: nil)
      captured = create(:payment, order: order, payment_method: check_method, amount: order.total, status: 'completed', response_code: nil)
      create(:refund, payment: captured, amount: 10)
      order.update_columns(payment_total: order.total - 10)
      top_up = create(:payment, order: order, payment_method: check_method, amount: 10, response_code: nil)

      order.process_payments!

      expect(top_up.reload.status).to be_in(%w[pending completed])
    end
  end

  describe 'retrying' do
    it 'processes a failed payment again — the failure may have been transient' do
      payment.update_column(:status, 'failed')
      allow(gateway).to receive(:capture_at_checkout?).and_return(false)
      expect(gateway).to receive(:authorize).and_return(success_response)

      expect(described_class.call(payment: payment)).to be_success
      expect(payment.reload).to be_pending
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
