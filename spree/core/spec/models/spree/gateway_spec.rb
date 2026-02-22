require 'spec_helper'

describe Spree::Gateway, type: :model do
  class Provider
    def initialize(options); end

    def imaginary_method; end
  end

  class TestGateway < Spree::Gateway
    preference :publishable_preference1, :string
    preference :publishable_preference2, :string
    preference :private_preference, :string

    def provider_class
      Provider
    end

    private

    def public_preference_keys
      [:publishable_preference1, :publishable_preference2]
    end
  end

  it 'passes through all arguments on a method_missing call' do
    gateway = TestGateway.new
    expect(gateway.provider).to receive(:imaginary_method).with('foo')
    gateway.imaginary_method('foo')
  end

  context 'Validations' do
    before do
      allow(Spree::PaymentMethod).to receive(:providers).and_return([TestGateway, Spree::Gateway::Bogus])
    end

    it 'validates the type' do
      expect(TestGateway.new.valid?).to be_truthy
    end

    it 'automatically sets the name' do
      expect(TestGateway.new.name).to eq('Test')
    end
  end

  context 'fetching payment sources' do
    let(:store) { @default_store }
    let(:order) { store.orders.create(user_id: 1, total: 100) }

    let(:has_card) { create(:credit_card_payment_method, stores: [store]) }
    let(:no_card) { create(:credit_card_payment_method, stores: [store]) }

    let(:cc) do
      create(:credit_card, payment_method: has_card, gateway_customer_profile_id: 'EFWE')
    end

    let(:payment) do
      create(:payment, order: order, source: cc, payment_method: has_card)
    end

    it 'finds credit cards associated on a order completed' do
      allow(payment.order).to receive_messages completed?: true

      expect(no_card.reusable_sources(payment.order)).to be_empty
      expect(has_card.reusable_sources(payment.order)).not_to be_empty
    end

    it 'finds credit cards associated with the order user' do
      cc.update_column :user_id, 1
      allow(payment.order).to receive_messages completed?: false

      expect(no_card.reusable_sources(payment.order)).to be_empty
      expect(has_card.reusable_sources(payment.order)).not_to be_empty
    end
  end

  it 'returns exchange multiplier for gateway' do
    gateway = TestGateway.new

    rate = Spree::Gateway::FROM_DOLLAR_TO_CENT_RATE
    expect(gateway.exchange_multiplier).to eq rate
  end

  it 'returns public preferences' do
    gateway = TestGateway.new
    gateway.preferences[:publishable_preference1] = 'public1'
    gateway.preferences[:publishable_preference2] = 'public2'
    gateway.preferences[:private_preference] = 'secret'

    expect(gateway.public_preferences).to eq({
      publishable_preference1: 'public1',
      publishable_preference2: 'public2'
    })
  end

  describe '#gateway_dashboard_payment_url' do
    let(:payment_method) { create(:credit_card_payment_method) }
    let(:payment) { create(:payment, payment_method: payment_method, transaction_id: '123') }

    it 'returns nil' do
      expect(payment_method.gateway_dashboard_payment_url(payment)).to be_nil
    end

    context 'when implemented' do
      before do
        expect(payment_method).to receive(:gateway_dashboard_payment_url).with(payment).and_return("https://dashboard.stripe.com/payments/#{payment.transaction_id}")
      end

      it 'returns the url' do
        expect(payment_method.gateway_dashboard_payment_url(payment)).to eq('https://dashboard.stripe.com/payments/123')
      end
    end
  end
end
