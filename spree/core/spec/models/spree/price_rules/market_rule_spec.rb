require 'spec_helper'

describe Spree::PriceRules::MarketRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:market_price_rule, price_list: price_list) }
  let(:market) { create(:market) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when market_ids preference is empty' do
      before { rule.preferred_market_ids = [] }

      it 'returns true for any market' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: market)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when market_ids preference is set' do
      before { rule.preferred_market_ids = [market.id] }

      it 'returns true when context market matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: market)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context market does not match' do
        other_market = create(:market)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: other_market)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no market' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: nil)
        expect(rule.applicable?(context)).to be false
      end
    end

    context 'when market_ids preference contains strings' do
      before { rule.preferred_market_ids = [market.id.to_s] }

      it 'returns true when context market matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: market)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context market does not match' do
        other_market = create(:market)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', market: other_market)
        expect(rule.applicable?(context)).to be false
      end
    end
  end

  describe '#preferred_market_ids=' do
    it 'decodes prefixed market IDs to raw IDs' do
      rule.preferred_market_ids = [market.prefixed_id]
      expect(rule.preferred_market_ids).to eq([market.id.to_s])
    end

    it 'accepts a mix of prefixed and raw IDs' do
      other_market = create(:market)
      rule.preferred_market_ids = [market.prefixed_id, other_market.id.to_s]
      expect(rule.preferred_market_ids).to contain_exactly(market.id.to_s, other_market.id.to_s)
    end

    it 'accepts a comma-separated string' do
      other_market = create(:market)
      rule.preferred_market_ids = "#{market.prefixed_id},#{other_market.prefixed_id}"
      expect(rule.preferred_market_ids).to contain_exactly(market.id.to_s, other_market.id.to_s)
    end

    it 'raises when given an unknown prefixed ID' do
      expect { rule.preferred_market_ids = ['mkt_doesnotexist'] }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#markets' do
    let(:other_market) { create(:market) }

    it 'returns the markets matching the preferred IDs' do
      rule.preferred_market_ids = [market.id, other_market.id]
      expect(rule.markets).to contain_exactly(market, other_market)
    end

    it 'returns empty when no markets are set' do
      rule.preferred_market_ids = []
      expect(rule.markets).to be_empty
    end
  end
end
