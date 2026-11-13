require 'spec_helper'

RSpec.describe Spree::CollectionRules::Seller, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let(:seller) { create(:seller, :approved, store: store) }
  let!(:listed) { create(:product, store: store, seller: seller) }
  let!(:operator_product) { create(:product, store: store) }

  it 'matches the seller products, or the others when negated' do
    rule = build(:seller_collection_rule, collection: collection, value: seller.prefixed_id)

    expect(rule.apply(store.products)).to contain_exactly(listed)
    rule.match_policy = 'is_not_equal_to'
    expect(rule.apply(store.products)).to contain_exactly(operator_product)
  end
end
