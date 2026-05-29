# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PriceRuleSerializer do
  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject(:payload) { described_class.new(rule, params: base_params).to_h }

  describe 'market rule' do
    let(:market) { create(:market, store: store) }
    let(:other_market) { create(:market, store: store) }
    let(:rule) do
      r = Spree::PriceRules::MarketRule.create!(price_list: price_list)
      r.preferred_market_ids = [market.id, other_market.id]
      r.save!
      r
    end

    it 'embeds the related markets' do
      ids = payload['markets'].map { |m| m['id'] }
      expect(ids).to contain_exactly(market.prefixed_id, other_market.prefixed_id)
    end

    it 'does not embed unrelated associations' do
      expect(payload).not_to have_key('customer_groups')
      expect(payload).not_to have_key('customers')
    end
  end

  describe 'customer group rule' do
    let(:customer_group) { create(:customer_group, store: store) }
    let(:rule) do
      r = Spree::PriceRules::CustomerGroupRule.create!(price_list: price_list)
      r.preferred_customer_group_ids = [customer_group.id]
      r.save!
      r
    end

    it 'embeds the related customer groups' do
      ids = payload['customer_groups'].map { |g| g['id'] }
      expect(ids).to contain_exactly(customer_group.prefixed_id)
    end

    it 'does not embed unrelated associations' do
      expect(payload).not_to have_key('markets')
      expect(payload).not_to have_key('customers')
    end
  end

  describe 'user (customer) rule' do
    let(:user) { create(:user) }
    let(:rule) do
      r = Spree::PriceRules::UserRule.create!(price_list: price_list)
      r.preferred_user_ids = [user.id]
      r.save!
      r
    end

    it 'embeds the related customers under the `customers` key' do
      ids = payload['customers'].map { |c| c['id'] }
      expect(ids).to contain_exactly(user.prefixed_id)
    end

    it 'does not embed unrelated associations' do
      expect(payload).not_to have_key('markets')
      expect(payload).not_to have_key('customer_groups')
    end
  end

  describe 'rule without embedded associations' do
    let(:rule) do
      Spree::PriceRules::VolumeRule.create!(price_list: price_list, preferred_min_quantity: 5)
    end

    it 'omits all three embed keys' do
      expect(payload).not_to have_key('markets')
      expect(payload).not_to have_key('customer_groups')
      expect(payload).not_to have_key('customers')
    end
  end

  describe 'prefixed-ID decoding via the API surface' do
    let(:market) { create(:market, store: store) }
    let(:rule) { Spree::PriceRules::MarketRule.create!(price_list: price_list) }

    it 'stores raw IDs when the wire sends prefixed IDs' do
      rule.preferred_market_ids = [market.prefixed_id]
      expect(rule.preferred_market_ids).to eq([market.id.to_s])
    end
  end
end
