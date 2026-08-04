require 'spec_helper'

RSpec.describe Spree::CollectionRules::Sale, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }

  # The four match policies are exercised via Collection#products_matching_rules;
  # here we cover the else (unknown-policy) fallback directly. build, not create,
  # bypasses the regeneration callback and the match_policy inclusion validation.
  describe '#apply' do
    let!(:on_sale) { create(:product, price: 10, compare_at_price: 12) }
    let!(:regular) { create(:product, price: 10) }
    let(:scope) { store.products.where(id: [on_sale.id, regular.id]) }

    it 'returns the scope unchanged for an unknown match policy' do
      rule = build(:sale_collection_rule, collection: collection, value: true, match_policy: 'bogus')

      expect(rule.apply(scope)).to contain_exactly(on_sale, regular)
    end
  end
end
