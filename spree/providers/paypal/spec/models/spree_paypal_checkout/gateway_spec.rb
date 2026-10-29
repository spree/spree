require 'spec_helper'

RSpec.describe SpreePaypalCheckout::Gateway do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store) }

  it 'is registered as a payment method' do
    expect(Rails.application.config.spree.payment_methods).to include(described_class)
  end

  it 'answers paypal_checkout as its api type' do
    expect(described_class.api_type).to eq('paypal_checkout')
  end

  it 'keeps the webhook id internal' do
    expect(gateway.preference_internal(:webhook_id)).to be(true)
  end

  it 'keeps the credentials secret' do
    expect(gateway.preference_type(:client_id)).to eq(:password)
    expect(gateway.preference_type(:client_secret)).to eq(:password)
  end

  it 'starts in test mode' do
    expect(described_class.new.preferred_test_mode).to be(true)
  end

  it 'requires a payment session' do
    expect(gateway.session_required?).to be(true)
    expect(gateway.payment_session_class).to eq(Spree::PaymentSessions::PaypalCheckout)
  end

  it 'saves no payment profiles' do
    expect(gateway.payment_profiles_supported?).to be(false)
  end

  it 'takes money amounts' do
    expect(described_class.accepts_money_amounts).to be(true)
  end
end
