require 'spec_helper'

describe Spree::PriceRules::DateRangeRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:date_range_price_rule, price_list: price_list) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'with starts_at and ends_at set' do
      before do
        rule.preferred_starts_at = 1.day.ago
        rule.preferred_ends_at = 1.day.from_now
      end

      it 'returns true when date is within range' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', date: Time.current)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when date is before range' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', date: 2.days.ago)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when date is after range' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', date: 2.days.from_now)
        expect(rule.applicable?(context)).to be false
      end
    end
  end
end
