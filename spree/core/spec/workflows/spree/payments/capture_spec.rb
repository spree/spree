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

  def money(amount, currency = 'USD')
    Spree::Money.new(BigDecimal(amount.to_s), currency: currency)
  end

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'capturing' do
    it 'captures at the gateway, records the capture event and publishes' do
      expect(gateway).to receive(:capture).with(money('45.75'), '123', anything).and_return(success_response)
      expect(payment).to receive(:publish_event).with('payment.completed')
      expect(payment).to receive(:publish_event).with('payment.captured')

      result = described_class.call(payment: payment)

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.capture_events.sum(:amount)).to eq(45.75)
    end

    it 'splits a partial capture into a pending remainder and re-authorizes it' do
      expect(gateway).to receive(:capture).with(money('10'), '123', anything).and_return(success_response)
      expect(gateway).to receive(:authorize)
        .and_return(Spree::PaymentResponse.new(true, nil, {}, authorization: '456'))

      result = described_class.call(payment: payment, amount: BigDecimal('10'))

      expect(result).to be_success
      expect(payment.reload).to be_completed
      expect(payment.amount).to eq(10.00)

      remainder = order.payments.pending.last
      expect(remainder.amount).to eq(35.75)
    end

    it "rounds a computed capture to the currency's decimals before recording it" do
      expect(gateway).to receive(:capture).with(money('10.04'), '123', anything).and_return(success_response)
      allow(gateway).to receive(:authorize).and_return(Spree::PaymentResponse.new(true, nil, {}, authorization: '456'))

      described_class.call(payment: payment, amount: BigDecimal('10.0375'))

      expect(payment.capture_events.sum(:amount)).to eq(BigDecimal('10.04'))
    end

    context 'with exact amounts' do
      %w[0.29 1.15 1234567.89].each do |amount|
        it "records a capture of #{amount} to the cent" do
          payment.update_columns(amount: BigDecimal(amount))
          order.update_columns(total: BigDecimal(amount))
          expect(gateway).to receive(:capture).with(money(amount), '123', anything).and_return(success_response)

          described_class.call(payment: payment)

          expect(payment.reload.captured_amount).to eq(BigDecimal(amount))
        end
      end

      it 'records a yen capture in yen and hands the gateway yen' do
        payment.update_columns(amount: BigDecimal('1000'))
        order.update_columns(currency: 'JPY', total: BigDecimal('1000'))
        expect(gateway).to receive(:capture).with(money('1000', 'JPY'), '123', anything).and_return(success_response)

        expect(described_class.call(payment: payment)).to be_success

        expect(payment.reload.captured_amount).to eq(BigDecimal('1000'))
        expect(payment.amount).to eq(BigDecimal('1000'))
      end

      it 'records a dinar capture to the thousandth' do
        payment.update_columns(amount: BigDecimal('1.5'))
        order.update_columns(currency: 'KWD', total: BigDecimal('1.5'))
        expect(gateway).to receive(:capture).with(money('1.5', 'KWD'), '123', anything).and_return(success_response)

        described_class.call(payment: payment)

        expect(payment.reload.captured_amount).to eq(BigDecimal('1.5'))
      end

      it 'still reads an Integer amount as hundredths, with a deprecation warning' do
        expect(Spree::Deprecation).to receive(:warn).with(/Integer amount/)
        expect(gateway).to receive(:capture).with(money('10'), '123', anything).and_return(success_response)
        allow(gateway).to receive(:authorize).and_return(Spree::PaymentResponse.new(true, nil, {}, authorization: '456'))

        described_class.call(payment: payment, amount: 1000)
      end
    end

    it 'is a no-op for an already-captured payment' do
      completed = create(:payment, payment_method: gateway, source: card, status: 'completed')
      expect(gateway).not_to receive(:capture)

      expect(described_class.call(payment: completed)).to be_success
    end

    it 'retries a failed capture — a failure can be a transient gateway outage' do
      payment.update_column(:status, 'failed')
      expect(gateway).to receive(:capture).with(money('45.75'), '123', anything).and_return(success_response)

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
