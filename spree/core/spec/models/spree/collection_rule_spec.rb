require 'spec_helper'

RSpec.describe Spree::CollectionRule, type: :model do

  it_behaves_like 'type labels'

  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }

  describe 'automatic flag' do
    let(:manual) { create(:collection, store: store) }

    it 'follows whether the collection has rules, claiming legacy memberships as hand-picked first' do
      legacy = create(:product_collection, collection: manual).tap { |row| row.update_columns(source: nil) }

      rule = create(:tag_collection_rule, collection: manual, value: 'sale')
      expect(manual.reload).to be_automatic
      expect(legacy.reload.source).to eq('manual')

      rule.destroy!
      expect(manual.reload).not_to be_automatic
    end
  end

  describe '.types_listing' do
    it 'lists the relations and whether a value is needed for each type' do
      price = described_class.types_listing.find { |entry| entry[:type] == 'price' }
      in_stock = described_class.types_listing.find { |entry| entry[:type] == 'in_stock' }

      expect(price).to include(match_policies: %w[greater_than less_than], value_required: true)
      expect(in_stock).to include(value_required: false)
    end
  end

  describe '#rule_currency' do
    it 'falls back to the store default currency' do
      expect(build(:sale_collection_rule, collection: collection).rule_currency).to eq(store.default_currency)
      expect(build(:sale_collection_rule, collection: collection, currency: 'eur').rule_currency).to eq('EUR')
    end
  end

  describe 'validations' do
    it 'rejects an unknown match_policy' do
      rule = build(:tag_collection_rule, collection: collection, value: 'sale', match_policy: 'nonsense')

      expect(rule).not_to be_valid
      expect(rule.errors[:match_policy]).to be_present
    end
  end

  # Assert the callback reaches the collection's regeneration; stub only the
  # effect (the 1c service that fulfills it).
  describe 'regeneration callback' do
    before { allow(collection).to receive(:regenerate_products) }

    it 'regenerates the collection products when a rule is created' do
      expect(collection).to receive(:regenerate_products).with(only_once: true)

      create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')
    end

    it 'regenerates when the value changes' do
      rule = create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')

      expect(collection).to receive(:regenerate_products).with(only_once: true)
      rule.update!(value: 'new-sale')
    end

    it 'regenerates when the rule is destroyed' do
      rule = create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale')

      expect(collection).to receive(:regenerate_products).with(only_once: true)
      rule.destroy!
    end
  end
end
