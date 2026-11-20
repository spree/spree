require 'spec_helper'

RSpec.describe SpreeAdyen::Gateway, 'webhooks' do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, :configured, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:merchant) { gateway.preferred_merchant_account }
  let(:minor_units) { SpreeAdyen::Amounts.to_adyen(order.total, order.currency) }
  let(:amount) { { 'value' => minor_units, 'currency' => order.currency } }

  def parse(body)
    gateway.parse_webhook_event(body, {})
  end

  def webhook(name, **overrides)
    adyen_webhook(name, merchantAccountCode: merchant, amount: amount, **overrides)
  end

  describe 'verification' do
    let(:session) { create(:adyen_payment_session, owner: order, payment_method: gateway, amount: order.total) }

    it 'refuses a malformed body' do
      expect { parse('not json') }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end

    it 'refuses a bad signature' do
      expect { parse(webhook('authorisation', hmac_key: 'AB' * 32)) }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end

    it 'accepts a delivery signed with the previous key' do
      gateway.update!(preferred_previous_hmac_key: 'CD' * 32)

      expect { parse(webhook('capture', hmac_key: 'CD' * 32)) }.not_to raise_error
    end

    it 'refuses another merchant account' do
      expect { parse(adyen_webhook('capture', merchantAccountCode: 'OtherECOM')) }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end

    it 'refuses the wrong live flag' do
      expect { parse(webhook('capture', live: 'true')) }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end

    it 'refuses a body with two items' do
      body = JSON.parse(webhook('capture'))
      body['notificationItems'] << body['notificationItems'][0]

      expect { parse(body.to_json) }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
    end
  end

  describe 'AUTHORISATION' do
    let!(:session) do
      create(:adyen_payment_session, owner: order, payment_method: gateway, amount: order.total,
                                     external_id: 'CS0000000000SESSION', external_data: { 'manual_capture' => false })
    end

    it 'settles the session as captured, with the report as metadata' do
      result = parse(webhook('authorisation'))

      expect(result).to include(action: :captured, payment_session: session)
      expect(result[:metadata]).to include('psp_reference' => 'PSPAUTH000000001', 'variant' => 'visa')
    end

    it 'settles as authorized when the session asked Adyen to hold the money' do
      session.update!(external_data: { 'manual_capture' => true })

      expect(parse(webhook('authorisation'))[:action]).to eq(:authorized)
    end

    it 'does not act on a refused attempt' do
      expect(parse(webhook('authorisation', success: 'false'))).to be_nil
    end

    it 'does not act on an authorisation without a session id' do
      expect(parse(webhook('authorisation', additionalData: { 'checkoutSessionId' => nil }))).to be_nil
    end

    it "does not act on another method's session" do
      session.update_columns(payment_method_id: create(:adyen_gateway, :configured, store: store).id)

      expect(parse(webhook('authorisation'))).to be_nil
    end

    it 'does not act on a payment for another amount' do
      expect(parse(webhook('authorisation', amount: { 'value' => minor_units + 1, 'currency' => order.currency }))).to be_nil
    end
  end

  describe 'modifications' do
    let(:payment) { adyen_session_payment(gateway: gateway, order: order, status: 'requested', psp_reference: 'PSPAUTH000000001') }
    let!(:capture_event) { create(:payment_capture_event, :requested, payment: payment, transaction_id: 'PSPMODIFICATION1') }

    let(:captured) { SpreeAdyen::Amounts.from_adyen(minor_units, order.currency).to_d.to_s('F') }

    it "maps CAPTURE to the capture's PSP reference and the amount taken" do
      expect(parse(webhook('capture'))).to eq(
        action: :capture_succeeded, reference: 'PSPMODIFICATION1', payment: nil, metadata: { 'amount' => captured }
      )
    end

    it 'maps a refused CAPTURE and CAPTURE_FAILED to a failed capture, with the reason' do
      expect(parse(webhook('capture', success: 'false', reason: 'Expired'))).to eq(
        action: :capture_failed, reference: 'PSPMODIFICATION1', payment: nil, metadata: { 'reason' => 'Expired', 'amount' => captured }
      )
      expect(parse(webhook('capture_failed'))[:action]).to eq(:capture_failed)
    end

    it 'names an outcome Spree has not recorded yet, so core waits for its record' do
      capture_event.destroy

      expect(parse(webhook('capture', pspReference: 'PSPUNKNOWN000002'))[:reference]).to eq('PSPUNKNOWN000002')
    end

    it 'names the payment a capture was asked for while the payment is processing' do
      payment.update_columns(status: 'processing')

      expect(parse(webhook('capture'))[:payment]).to eq(payment)
    end

    it "names an automatic capture's late failure by the payment's reference" do
      capture_event.update_columns(transaction_id: 'PSPAUTH000000001')

      expect(parse(webhook('capture_failed', pspReference: 'PSPUNKNOWN000001'))[:reference]).to eq('PSPAUTH000000001')
    end

    it 'maps CANCELLATION to the reference of the payment it released' do
      expect(parse(webhook('cancellation'))).to eq(action: :void_succeeded, reference: 'PSPAUTH000000001', metadata: {})
      expect(parse(webhook('cancellation', success: 'false'))[:action]).to eq(:void_failed)
    end

    it "maps REFUND, REFUND_FAILED and REFUNDED_REVERSED to the refund's PSP reference" do
      expect(parse(webhook('refund'))).to eq(action: :refund_succeeded, reference: 'PSPMODIFICATION1', metadata: {})
      expect(parse(webhook('refund', success: 'false'))[:action]).to eq(:refund_failed)
      expect(parse(webhook('refund_failed'))[:action]).to eq(:refund_failed)
      expect(parse(webhook('refunded_reversed'))[:action]).to eq(:refund_failed)
    end

    it 'does not act on an outcome that names no reference' do
      expect(parse(webhook('refund', pspReference: ''))).to be_nil
    end
  end

  describe '#modification_record' do
    let!(:payment) { adyen_session_payment(gateway: gateway, order: order, status: 'requested', psp_reference: 'PSPAUTH000000001') }

    it 'finds a cancel by the PSP reference of the payment waiting on it' do
      expect(gateway.modification_record(:void_succeeded, 'PSPAUTH000000001')).to eq(payment)

      payment.update_columns(status: 'pending')
      expect(gateway.modification_record(:void_succeeded, 'PSPAUTH000000001')).to be_nil
    end

    it "finds captures and refunds by core's default" do
      payment.update_columns(status: 'completed')
      refund = create(:refund, :requested, payment: payment, amount: 1, transaction_id: 'PSPMODIFICATION1')

      expect(gateway.modification_record(:refund_failed, 'PSPMODIFICATION1')).to eq(refund)
      expect(gateway.modification_record(:capture_succeeded, 'PSPMODIFICATION9')).to be_nil
    end

    it 'does not act on other events' do
      expect(parse(webhook('capture', eventCode: 'REPORT_AVAILABLE'))).to be_nil
    end
  end
end
