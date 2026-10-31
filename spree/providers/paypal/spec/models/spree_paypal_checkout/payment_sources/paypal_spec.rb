require 'spec_helper'

RSpec.describe SpreePaypalCheckout::PaymentSources::Paypal do
  subject(:source) do
    described_class.for_payment_source(payment_source, payment_method: gateway, customer: customer, paypal_order_id: 'ORDER1234567890AB')
  end

  let(:gateway) { create(:paypal_checkout_gateway) }
  let(:customer) { create(:customer) }

  context 'with a PayPal wallet' do
    let(:payment_source) do
      {
        'paypal' => {
          'email_address' => 'buyer@example.com', 'account_id' => 'PAYERID1234', 'account_status' => 'VERIFIED',
          'name' => { 'given_name' => 'Ada', 'surname' => 'Lovelace' }
        }
      }
    end

    it 'records the account' do
      expect(source).to be_persisted
      expect(source.gateway_payment_profile_id).to eq('paypal-ORDER1234567890AB')
      expect(source.customer).to eq(customer)
      expect(source.metadata).to eq(
        'wallet' => 'paypal', 'email' => 'buyer@example.com', 'name' => 'Ada Lovelace',
        'account_id' => 'PAYERID1234', 'account_status' => 'VERIFIED'
      )
    end

    it 'keeps another customer paying with the same account on a source of their own' do
      other = create(:customer)
      theirs = described_class.for_payment_source(payment_source, payment_method: gateway, customer: other, paypal_order_id: 'A')

      expect(source).not_to eq(theirs)
      expect(theirs.customer).to eq(other)
      expect(source.customer).to eq(customer)
    end

    it 'returns the same source when the order settles again' do
      again = described_class.for_payment_source(payment_source, payment_method: gateway, customer: customer, paypal_order_id: 'ORDER1234567890AB')

      expect(again).to eq(source)
    end
  end

  context 'with a Venmo wallet' do
    let(:payment_source) { { 'venmo' => { 'email_address' => 'buyer@example.com', 'account_id' => 'VENMO123', 'user_name' => 'ada' } } }

    it 'records it as Venmo' do
      expect(source.wallet).to eq('venmo')
      expect(source.metadata['user_name']).to eq('ada')
    end
  end

  context 'with a card paid in PayPal\'s window' do
    let(:payment_source) { { 'card' => { 'name' => 'Ada Lovelace', 'last_digits' => '4242', 'brand' => 'VISA', 'type' => 'CREDIT' } } }

    it 'records the brand and last digits on a PayPal source, never a credit card' do
      expect(source).to be_a(described_class)
      expect(source.wallet).to eq('card')
      expect(source.brand).to eq('VISA')
      expect(source.last_digits).to eq('4242')
      expect(Spree::CreditCard.count).to eq(0)
    end

    it 'records a card PayPal reports without details' do
      source = described_class.for_payment_source({ 'card' => {} }, payment_method: gateway, customer: nil, paypal_order_id: 'B')

      expect(source.metadata).to eq('wallet' => 'card')
    end
  end

  context 'with a kind the gem does not model' do
    let(:payment_source) { { 'ideal' => { 'name' => 'Ada' } } }

    it { is_expected.to be_nil }
  end

  context 'without a payment source' do
    let(:payment_source) { nil }

    it { is_expected.to be_nil }
  end

  it 'is named PayPal' do
    expect(described_class.display_name).to eq('PayPal')
  end
end
