require 'spec_helper'

RSpec.describe Spree::CollectionRules::Tag, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }

  # #apply covers each tag match policy directly (build, not create, to bypass the
  # regeneration callback and the value/match_policy validations for the else branch).
  describe '#apply' do
    let!(:sale) { create(:product, tag_list: 'sale') }
    let!(:new_arrival) { create(:product, tag_list: 'new') }
    let!(:both) { create(:product, tag_list: 'sale, new') }
    let(:scope) { store.products.where(id: [sale.id, new_arrival.id, both.id]) }

    def tag_rule(match_policy)
      build(:tag_collection_rule, collection: collection, value: 'sale', match_policy: match_policy)
    end

    it 'is_equal_to matches products carrying the tag' do
      expect(tag_rule('is_equal_to').apply(scope)).to contain_exactly(sale, both)
    end

    it 'is_not_equal_to excludes products carrying the tag' do
      expect(tag_rule('is_not_equal_to').apply(scope)).to contain_exactly(new_arrival)
    end

    it 'contains matches products carrying any of the tag' do
      expect(tag_rule('contains').apply(scope)).to contain_exactly(sale, both)
    end

    it 'does_not_contain excludes products carrying any of the tag' do
      expect(tag_rule('does_not_contain').apply(scope)).to contain_exactly(new_arrival)
    end

    it 'returns the scope unchanged for an unknown match policy' do
      expect(tag_rule('bogus').apply(scope)).to contain_exactly(sale, new_arrival, both)
    end
  end
end
