require 'spec_helper'

RSpec.describe Spree::CollectionRules::InStock, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let!(:stocked) { create(:product, store: store).tap { |product| product.default_variant.stock_levels.update_all(count_on_hand: 5) } }
  let!(:sold_out) do
    create(:product, store: store).tap do |product|
      product.default_variant.stock_levels.update_all(count_on_hand: 0, backorderable: false)
    end
  end

  it 'takes no value' do
    expect(build(:in_stock_collection_rule, collection: collection, value: nil)).to be_valid
  end

  it 'matches products that can be sold now, or the others when negated' do
    rule = build(:in_stock_collection_rule, collection: collection)

    expect(rule.apply(store.products)).to include(stocked)
    expect(rule.apply(store.products)).not_to include(sold_out)
    rule.match_policy = 'is_not_equal_to'
    expect(rule.apply(store.products)).to include(sold_out)
    expect(rule.apply(store.products)).not_to include(stocked)
  end
end
