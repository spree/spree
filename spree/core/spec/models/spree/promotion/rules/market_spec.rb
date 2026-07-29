require 'spec_helper'

describe Spree::Promotion::Rules::Market, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, store: store) }
  let(:rule) { described_class.new(promotion: promotion) }
  let(:market) { create(:market, store: store) }
  let(:other_market) { create(:market, store: store) }

  describe '#applicable?' do
    it 'returns true for orders' do
      expect(rule.applicable?(build(:order))).to be true
    end

    it 'returns false for non-orders' do
      expect(rule.applicable?('not an order')).to be false
    end
  end

  describe '#eligible?' do
    context 'when no markets are configured' do
      before { rule.preferred_market_ids = [] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(build(:order, store: store))
      end
    end

    context "when the order's market is in the configured list" do
      before { rule.preferred_market_ids = [market.id] }

      it 'is eligible' do
        expect(rule).to be_eligible(build(:order, store: store, market: market))
      end
    end

    context "when the order's market is not in the configured list" do
      before { rule.preferred_market_ids = [market.id] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(build(:order, store: store, market: other_market))
      end
    end

    context 'when the order matches one of multiple configured markets' do
      before { rule.preferred_market_ids = [market.id, other_market.id] }

      it 'is eligible' do
        expect(rule).to be_eligible(build(:order, store: store, market: other_market))
      end
    end

    context 'when configured with prefixed IDs' do
      before { rule.preferred_market_ids = [market.prefixed_id] }

      it 'decodes them and matches' do
        expect(rule).to be_eligible(build(:order, store: store, market: market))
      end
    end
  end

  describe '#markets' do
    it 'returns the configured markets scoped to the store' do
      rule.preferred_market_ids = [market.id]
      expect(rule.markets).to contain_exactly(market)
    end

    it 'returns none when unconfigured' do
      expect(rule.markets).to be_empty
    end
  end

  context 'when configured with a market from another store' do
    let(:other_store) { create(:store) }
    let(:foreign_market) { create(:market, store: other_store) }

    it 'rejects the foreign ID' do
      expect { rule.preferred_market_ids = [foreign_market.id] }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
