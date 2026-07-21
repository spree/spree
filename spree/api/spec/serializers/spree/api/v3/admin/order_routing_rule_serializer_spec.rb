# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderRoutingRuleSerializer do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let(:rule) { channel.order_routing_rules.ordered.first }

  subject(:payload) { described_class.new(rule, params: { store: store, currency: 'USD' }).to_h }

  it 'serializes the wire shape the routing-rules editor consumes' do
    expect(payload['id']).to eq(rule.prefixed_id)
    expect(payload['type']).to eq('preferred_location')
    expect(payload['channel_id']).to eq(channel.prefixed_id)
    expect(payload['position']).to eq(1)
    expect(payload['active']).to be(true)
    expect(payload['label']).to eq('Preferred location')
    expect(payload['description']).to be_present
    expect(payload['preferences']).to eq({})
    expect(payload['preference_schema']).to eq([])
    expect(payload['created_at']).to be_present
    expect(payload['updated_at']).to be_present
  end

  describe 'preferences masking' do
    # Built-in rules declare no preferences; splice a `:password` preference
    # into the schema for the duration of the example so the masking path is
    # locked in for plugin-authored rules that carry secrets.
    let(:rule) do
      channel.order_routing_rules.ordered.first.tap do |r|
        r.preferences[:api_secret] = 'sk_rule_super_secret_value'

        stubbed_schema = [{ key: :api_secret, type: :password, default: nil }]
        allow(r.class).to receive(:preference_schema).and_return(stubbed_schema)
      end
    end

    it 'masks `:password` preferences and never leaks the plaintext' do
      expect(payload['preferences']['api_secret']).to eq("#{Spree::Preferences::Masking::TOKEN}alue")
      expect(payload.to_json).not_to include('sk_rule_super_secret_value')
    end
  end
end
