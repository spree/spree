# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PromotionRuleSerializer do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'preferences masking' do
    # Currency is the simplest concrete subclass of PromotionRule. As
    # with the action serializer spec, we splice a `:password` preference
    # into its schema for the duration of the example so the masking
    # path can be asserted without a full new STI subclass.
    let(:rule) do
      rule = Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')
      rule.preferences[:api_secret] = 'sk_rule_super_secret_value'

      stubbed_schema = [
        { key: :currency, type: :string, default: nil },
        { key: :api_secret, type: :password, default: nil }
      ]
      allow(rule.class).to receive(:preference_schema).and_return(stubbed_schema)
      rule
    end

    subject(:payload) { described_class.new(rule, params: base_params).to_h }

    it 'masks `:password` preferences in the serialized payload' do
      expect(payload['preferences']['api_secret']).to eq("#{Spree::Preferences::Masking::TOKEN}alue")
    end

    it 'never includes the plaintext secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_rule_super_secret_value')
    end

    it 'returns non-password preferences in plaintext' do
      expect(payload['preferences']['currency']).to eq('USD')
    end
  end
end
