require 'spec_helper'

RSpec.describe Spree::CollectionRules::Title, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let!(:shirt) { create(:product, store: store, name: 'Linen Shirt') }
  let!(:jacket) { create(:product, store: store, name: 'Shirt Jacket') }
  let!(:percent) { create(:product, store: store, name: '100% Wool') }

  def matches(policy, value)
    build(:title_collection_rule, collection: collection, match_policy: policy, value: value).apply(store.products)
  end

  it 'compares the name case-insensitively' do
    expect(matches('contains', 'shirt')).to contain_exactly(shirt, jacket)
    expect(matches('starts_with', 'shirt')).to contain_exactly(jacket)
    expect(matches('ends_with', 'SHIRT')).to contain_exactly(shirt)
    expect(matches('is_equal_to', 'linen shirt')).to contain_exactly(shirt)
    expect(matches('does_not_contain', 'shirt')).to contain_exactly(percent)
  end

  it 'treats wildcard characters as text' do
    expect(matches('contains', '%')).to contain_exactly(percent)
  end
end
