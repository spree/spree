# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PromotionActionSerializer do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'preferences masking' do
    # FreeShipping is the simplest concrete subclass of PromotionAction.
    # We splice a `:password` preference into its schema for the duration
    # of the example so the masking behaviour can be asserted without
    # needing a full new STI subclass + registry registration.
    let(:action) do
      action = Spree::Promotion::Actions::FreeShipping.create!(promotion: promotion)
      action.preferences[:api_secret] = 'sk_action_super_secret_value'
      action.preferences[:webhook_url] = 'https://example.com/hook'

      stubbed_schema = [
        { key: :api_secret, type: :password, default: nil },
        { key: :webhook_url, type: :string, default: nil }
      ]
      allow(action.class).to receive(:preference_schema).and_return(stubbed_schema)
      action
    end

    subject(:payload) { described_class.new(action, params: base_params).to_h }

    it 'masks `:password` preferences in the serialized payload' do
      expect(payload['preferences']['api_secret']).to eq("#{Spree::Preferences::Masking::TOKEN}alue")
    end

    it 'never includes the plaintext secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_action_super_secret_value')
    end

    it 'returns non-password preferences in plaintext' do
      expect(payload['preferences']['webhook_url']).to eq('https://example.com/hook')
    end
  end

  describe 'nested calculator preferences masking' do
    let(:action) do
      Spree::Promotion::Actions::CreateAdjustment.create!(
        promotion: promotion,
        calculator: Spree::Calculator::FlatRate.new(preferred_amount: 5)
      )
    end

    before do
      # Splice a `:password` preference into the calculator's schema so
      # the nested-calculator masking path is exercised end-to-end.
      action.calculator.preferences[:api_secret] = 'sk_calc_super_secret_value'
      stubbed_schema = [
        { key: :api_secret, type: :password, default: nil },
        { key: :amount, type: :decimal, default: 0 }
      ]
      allow(action.calculator.class).to receive(:preference_schema).and_return(stubbed_schema)
    end

    # The `calculator` attribute is a plain Ruby Hash returned from an
    # Alba block — its keys are symbols, while the inner `preferences`
    # hash is string-keyed (it's the wire-shape from `Masking.serialize`).
    subject(:payload) { described_class.new(action, params: { store: store, currency: 'USD' }).to_h }

    it 'masks `:password` preferences on the nested calculator' do
      expect(payload['calculator'][:preferences]['api_secret']).to eq('••••alue')
    end

    it 'never includes the plaintext calculator secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_calc_super_secret_value')
    end
  end
end
