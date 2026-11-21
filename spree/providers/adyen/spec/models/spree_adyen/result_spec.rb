require 'spec_helper'

RSpec.describe SpreeAdyen::Result do
  describe '.from_session_result' do
    let(:body) do
      {
        'id' => 'CS1234', 'status' => 'completed', 'reference' => 'cart_abc-1',
        'payments' => [{
          'pspReference' => 'PSP1', 'resultCode' => 'Authorised',
          'amount' => { 'value' => 1099, 'currency' => 'EUR' },
          'paymentMethod' => { 'type' => 'scheme', 'brand' => 'visa' },
          'additionalData' => { 'cardSummary' => '1111', 'expiryDate' => '03/2030', 'tokenization.storedPaymentMethodId' => 'STORED1' }
        }]
      }
    end

    it 'reads the payment, the card and the stored id' do
      result = described_class.from_session_result(body)

      expect(result).to have_attributes(
        psp_reference: 'PSP1', result_code: 'Authorised', session_status: 'completed', amount: BigDecimal('10.99'),
        currency: 'EUR', variant: 'visa', card_summary: '1111', expiry_month: '03', expiry_year: '2030',
        stored_payment_method_id: 'STORED1', merchant_reference: 'cart_abc-1', payments_count: 1
      )
      expect(result).to be_settleable
    end

    it 'names a wallet card by its brand and wallet' do
      body['payments'][0]['paymentMethod'] = { 'type' => 'applepay', 'brand' => 'visa' }

      expect(described_class.from_session_result(body).variant).to eq('visa_applepay')
    end
  end

  describe '.from_payment_details' do
    it 'reads a redirect payment' do
      result = described_class.from_payment_details(
        'pspReference' => 'PSP2', 'resultCode' => 'Received', 'merchantReference' => 'cart_abc-2',
        'amount' => { 'value' => 2500, 'currency' => 'EUR' }, 'paymentMethod' => { 'type' => 'ideal' }
      )

      expect(result).to have_attributes(psp_reference: 'PSP2', variant: 'ideal', amount: BigDecimal('25'), merchant_reference: 'cart_abc-2')
      expect(result).to be_pending
    end
  end

  describe '.from_notification' do
    it 'reads an AUTHORISATION item' do
      result = described_class.from_notification(
        'pspReference' => 'PSP3', 'success' => 'true', 'merchantReference' => 'cart_abc-3', 'paymentMethod' => 'mc',
        'reason' => '010388:4444:8/2031', 'amount' => { 'value' => 500, 'currency' => 'USD' },
        'additionalData' => { 'cardSummary' => '4444', 'expiryDate' => '8/2031', 'recurring.recurringDetailReference' => 'STORED3' }
      )

      expect(result).to have_attributes(psp_reference: 'PSP3', result_code: 'Authorised', variant: 'mc', amount: BigDecimal('5'),
                                        card_summary: '4444', stored_payment_method_id: 'STORED3', refusal_reason: nil)
    end

    it 'reads a refusal' do
      result = described_class.from_notification('pspReference' => 'PSP4', 'success' => 'false', 'reason' => 'Refused')

      expect(result).not_to be_settleable
      expect(result.refusal_reason).to eq('Refused')
    end
  end

  describe '#to_h' do
    it 'is JSON-safe with string keys and reads back' do
      result = described_class.new(psp_reference: 'PSP5', amount: BigDecimal('10.5'), currency: 'EUR', payments_count: 1)
      hash = result.to_h

      expect(hash.keys).to all(be_a(String))
      expect(JSON.parse(hash.to_json)).to eq(hash)
      expect(described_class.from_h(hash)).to have_attributes(psp_reference: 'PSP5', amount: BigDecimal('10.5'))
    end
  end
end
