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
end
