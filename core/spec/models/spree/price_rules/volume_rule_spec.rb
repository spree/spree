require 'spec_helper'

describe Spree::PriceRules::VolumeRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:volume_price_rule, price_list: price_list, min_quantity: 10) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    it 'returns true when quantity meets minimum' do
      context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', quantity: 10)
      expect(rule.applicable?(context)).to be true
    end

    it 'returns false when quantity is below minimum' do
      context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', quantity: 5)
      expect(rule.applicable?(context)).to be false
    end

    context 'with max_quantity set' do
      before { rule.preferred_max_quantity = 50 }

      it 'returns true when quantity is within range' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', quantity: 25)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when quantity exceeds maximum' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', quantity: 100)
        expect(rule.applicable?(context)).to be false
      end
    end

    it 'returns false when quantity is nil' do
      context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', quantity: nil)
      expect(rule.applicable?(context)).to be false
    end
  end
end
