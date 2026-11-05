require 'spec_helper'

RSpec.describe Spree::CollectionRules::Category, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let(:parent) { create(:category, store: store) }
  let(:child) { create(:category, store: store, parent: parent) }
  let!(:in_parent) { create(:product, store: store, categories: [parent]) }
  let!(:in_child) { create(:product, store: store, categories: [child]) }
  let!(:elsewhere) { create(:product, store: store) }
  let(:scope) { store.products }

  def rule(**attributes)
    build(:category_collection_rule, collection: collection, value: parent.prefixed_id, **attributes)
  end

  it 'stores the raw id and reads back the prefixed one' do
    expect(rule.value).to eq(parent.id.to_s)
    expect(rule.api_value).to eq(parent.prefixed_id)
  end

  it 'matches the category only by default' do
    expect(rule.apply(scope)).to contain_exactly(in_parent)
  end

  it 'matches subcategories when asked' do
    expect(rule(preferred_include_descendants: true).apply(scope)).to contain_exactly(in_parent, in_child)
  end

  it 'matches everything when negating a category that no longer exists' do
    negated = rule(match_policy: 'is_not_equal_to')
    parent.destroy!

    expect(negated.apply(scope)).to contain_exactly(in_parent, in_child, elsewhere)
  end

  it 'negates' do
    expect(rule(match_policy: 'is_not_equal_to').apply(scope)).to contain_exactly(in_child, elsewhere)
  end

  it 'refuses a category of another store' do
    foreign = create(:category, store: create(:store))

    expect(rule(value: foreign.prefixed_id)).not_to be_valid
  end

  it 'refuses relations it does not support' do
    expect(rule(match_policy: 'contains')).not_to be_valid
  end
end
