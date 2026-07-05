require 'spec_helper'

describe Spree::PriceHistory, type: :model do
  describe 'scopes' do
    let(:variant) { create(:variant) }
    let(:price) { variant.default_price }

    before do
      # Materialize lets, then clear history created by variant/price setup
      price
      Spree::PriceHistory.delete_all

      create(:price_history, price: price, variant: variant, amount: 10.0, currency: 'USD', recorded_at: 5.days.ago)
      create(:price_history, price: price, variant: variant, amount: 15.0, currency: 'USD', recorded_at: 20.days.ago)
      create(:price_history, price: price, variant: variant, amount: 25.0, currency: 'USD', recorded_at: 45.days.ago)
    end

    describe '.recent' do
      it 'returns records within the default 30-day window' do
        expect(described_class.recent.count).to eq(2)
      end

      it 'respects custom day count' do
        expect(described_class.recent(10).count).to eq(1)
      end
    end

    describe '.for_currency' do
      it 'filters by currency' do
        create(:price_history, price: price, variant: variant, amount: 5.0, currency: 'EUR', recorded_at: 1.day.ago)

        expect(described_class.for_currency('USD').count).to eq(3)
        expect(described_class.for_currency('EUR').count).to eq(1)
      end
    end
  end
end
