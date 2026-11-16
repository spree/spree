require 'spec_helper'

RSpec.describe SpreeAdyen::Gateway do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }

  describe 'declarations' do
    it 'is registered as a payment method' do
      expect(Rails.application.config.spree.payment_methods).to include(described_class)
    end

    it 'answers adyen as its api type' do
      expect(described_class.api_type).to eq('adyen')
    end

    it 'asks the operator for four fields and hides the ones configuration writes' do
      keys = described_class.serialized_preference_schema.pluck(:key)

      expect(keys).to contain_exactly(:api_key, :merchant_account, :test_mode, :live_url_prefix)
      %i[client_key hmac_key previous_hmac_key webhook_id].each do |key|
        expect(gateway.preference_internal(key)).to be(true)
      end
    end

    it 'keeps the keys secret' do
      %i[api_key client_key hmac_key previous_hmac_key].each do |key|
        expect(gateway.preference_type(key)).to eq(:password)
      end
    end

    it 'starts in test mode' do
      expect(described_class.new.preferred_test_mode).to be(true)
    end

    it 'requires a live URL prefix only outside test mode' do
      expect(gateway).to be_valid

      gateway.preferred_test_mode = false
      expect(gateway).not_to be_valid
      expect(gateway.errors[:preferred_live_url_prefix]).to be_present

      gateway.preferred_live_url_prefix = '1797a841fbb37ca7-AdyenDemo'
      expect(gateway).to be_valid
    end

    it 'takes money amounts, a payment session and saved cards' do
      expect(described_class.accepts_money_amounts).to be(true)
      expect(gateway.session_required?).to be(true)
      expect(gateway.payment_profiles_supported?).to be(true)
    end

    it 'names its gallery logo and guide' do
      expect(described_class.logo_url).to end_with('adyen.png')
      expect(described_class.docs_url).to end_with('/integrations/payments/adyen')
    end
  end

  describe 'stored names' do
    it 'loads a payment method row as 5.x left it' do
      row = Spree::PaymentMethod.where(id: gateway.id).pick(:type)

      expect(row).to eq('SpreeAdyen::Gateway')
      expect(Spree::PaymentMethod.find(gateway.id)).to be_a(described_class)
    end

    it 'resolves both session classes by their stored names' do
      expect(gateway.payment_session_class).to eq('Spree::PaymentSessions::Adyen'.constantize)
      expect(gateway.payment_setup_session_class).to eq('Spree::PaymentSetupSessions::Adyen'.constantize)
      expect(Spree::PaymentSessions::Adyen.superclass).to eq(Spree::PaymentSession)
      expect(Spree::PaymentSetupSessions::Adyen.superclass).to eq(Spree::PaymentSetupSession)
    end
  end
end
