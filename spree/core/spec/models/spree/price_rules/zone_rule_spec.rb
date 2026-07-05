require 'spec_helper'

describe Spree::PriceRules::ZoneRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:zone_price_rule, price_list: price_list) }
  let(:zone) { create(:zone) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when zone_ids preference is empty' do
      before { rule.preferred_zone_ids = [] }

      it 'returns true for any zone' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', zone: zone)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when zone_ids preference is set' do
      before { rule.preferred_zone_ids = [zone.id] }

      it 'returns true when context zone matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', zone: zone)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context zone does not match' do
        other_zone = create(:zone)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', zone: other_zone)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no zone' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end

    context 'when zone_ids preference contains strings' do
      before { rule.preferred_zone_ids = [zone.id.to_s] }

      it 'returns true when context zone matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', zone: zone)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context zone does not match' do
        other_zone = create(:zone)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', zone: other_zone)
        expect(rule.applicable?(context)).to be false
      end
    end
  end
end
