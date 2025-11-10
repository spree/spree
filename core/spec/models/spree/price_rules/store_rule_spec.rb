require 'spec_helper'

describe Spree::PriceRules::StoreRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:store_price_rule, price_list: price_list) }
  let(:store) { create(:store) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when store_ids preference is empty' do
      before { rule.preferred_store_ids = [] }

      it 'returns true for any store' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when store_ids preference is set' do
      before { rule.preferred_store_ids = [store.id] }

      it 'returns true when context store matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context store does not match' do
        other_store = create(:store)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: other_store)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no store' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end
  end
end
