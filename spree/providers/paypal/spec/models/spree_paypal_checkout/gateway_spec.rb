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

  describe '#available_for_order?' do
    let(:cart) { create(:cart_with_line_items, store: store) }

    it 'is true for a currency PayPal takes' do
      expect(gateway.available_for_order?(cart)).to be(true)
    end

    it 'is false for a currency PayPal does not take' do
      cart.update_columns(currency: 'INR')

      expect(gateway.available_for_order?(cart)).to be(false)
    end
  end

  describe '#paypal_intent' do
    it 'captures for a method that captures at checkout' do
      gateway.update!(capture_method: 'checkout')

      expect(gateway.paypal_intent).to eq('CAPTURE')
    end

    it 'authorizes for a method that captures on dispatch' do
      gateway.update!(capture_method: 'on_dispatch')

      expect(gateway.paypal_intent).to eq('AUTHORIZE')
    end

    it 'authorizes for a method captured by hand' do
      gateway.update!(capture_method: 'manual')

      expect(gateway.paypal_intent).to eq('AUTHORIZE')
    end
  end
end
