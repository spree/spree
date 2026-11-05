require 'spec_helper'

RSpec.describe Spree::CollectionRules::CustomField, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let(:material) { create(:custom_field_definition, store: store, collection_condition: true) }
  let(:weight) { create(:custom_field_definition, :number_field, store: store, collection_condition: true) }
  let(:hidden) { create(:custom_field_definition, store: store) }
  let!(:linen) { create(:product, store: store) }
  let!(:wool) { create(:product, store: store) }

  before do
    create(:custom_field, resource: linen, custom_field_definition: material, value: 'Linen blend')
    create(:custom_field, resource: wool, custom_field_definition: material, value: 'Wool')
    create(:custom_field, :number, resource: linen, custom_field_definition: weight, value: 120)
    create(:custom_field, :number, resource: wool, custom_field_definition: weight, value: 450)
  end

  def rule(definition, **attributes)
    build(:custom_field_collection_rule, collection: collection, preferred_custom_field_definition_id: definition.prefixed_id, **attributes)
  end

  it 'compares text fields as text' do
    expect(rule(material, match_policy: 'contains', value: 'linen').apply(store.products)).to contain_exactly(linen)
    expect(rule(material, match_policy: 'is_not_equal_to', value: 'Wool').apply(store.products)).to contain_exactly(linen)
  end

  it 'compares number fields as numbers' do
    expect(rule(weight, match_policy: 'greater_than', value: '200').apply(store.products)).to contain_exactly(wool)
    expect(rule(weight, match_policy: 'less_than', value: '200').apply(store.products)).to contain_exactly(linen)
  end

  it 'only accepts definitions marked as collection conditions' do
    expect(rule(hidden, value: 'x')).not_to be_valid
  end

  it 'refuses relations the field type does not support' do
    expect(rule(material, match_policy: 'greater_than', value: '1')).not_to be_valid
    expect(rule(weight, match_policy: 'contains', value: '1')).not_to be_valid
    expect(rule(weight, match_policy: 'greater_than', value: 'heavy')).not_to be_valid
  end
end
