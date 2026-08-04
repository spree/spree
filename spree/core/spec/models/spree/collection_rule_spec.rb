require 'spec_helper'

RSpec.describe Spree::CollectionRule, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }

  describe 'validations' do
    it 'rejects an unknown match_policy' do
      rule = build(:tag_collection_rule, collection: collection, value: 'sale', match_policy: 'nonsense')

      expect(rule).not_to be_valid
      expect(rule.errors[:match_policy]).to be_present
    end

    it 'requires a value' do
      rule = build(:tag_collection_rule, :is_equal_to, collection: collection, value: nil)

      expect(rule).not_to be_valid
      expect(rule.errors[:value]).to be_present
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
