require 'spec_helper'

RSpec.describe Spree::CollectionRules::ProductType, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let(:shoes) { create(:product_type, store: store) }
  let!(:shoe) { create(:product, store: store, product_type: shoes) }
  let!(:untyped) { create(:product, store: store) }

  def rule(**attributes)
    build(:product_type_collection_rule, collection: collection, value: shoes.prefixed_id, **attributes)
  end

  it 'matches products of the type, or every other product when negated' do
    expect(rule.apply(store.products)).to contain_exactly(shoe)
    expect(rule(match_policy: 'is_not_equal_to').apply(store.products)).to contain_exactly(untyped)
  end

  it 'refuses another model prefixed id' do
    expect(rule(value: shoe.prefixed_id)).not_to be_valid
  end
end
