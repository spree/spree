require 'spec_helper'

RSpec.describe Spree::CollectionRules::AvailableOn, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }

  describe '#apply' do
    let!(:recent_product) { create(:product).tap { |p| p.update_columns(available_on: 1.day.ago) } }
    let!(:old_product) do
      create(:product).tap { |p| p.update_columns(available_on: 90.days.ago, created_at: 90.days.ago) }
    end

    it 'matches products created or available within the window' do
      rule = build(:available_on_collection_rule, :is_equal_to, collection: collection, value: 30)

      result = rule.apply(store.products.not_archived)

      expect(result).to include(recent_product)
      expect(result).not_to include(old_product)
    end

    it 'returns the scope unchanged for an unhandled match policy' do
      rule = build(:available_on_collection_rule, collection: collection, value: 30, match_policy: 'is_not_equal_to')

      result = rule.apply(store.products.not_archived)

      expect(result).to include(recent_product, old_product)
    end
  end
end
