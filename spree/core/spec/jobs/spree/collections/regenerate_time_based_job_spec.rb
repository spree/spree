require 'spec_helper'

module Spree
  RSpec.describe Collections::RegenerateTimeBasedJob do
    let(:store) { @default_store }
    let!(:collection) { create(:automatic_collection, store: store) }
    let!(:rule) { create(:available_on_collection_rule, :is_equal_to, collection: collection, value: 30) }
    let!(:product) { create(:product) }

    # Materialize membership while the product is fresh (within the 30-day window).
    before { Spree::Collections::RegenerateProducts.call(collection: collection) }

    it 'drops a product that has aged out of the window' do
      expect(collection.reload.products).to include(product)

      product.update_columns(created_at: 90.days.ago, available_on: 90.days.ago, updated_at: 90.days.ago)

      described_class.perform_now

      expect(collection.reload.products).not_to include(product)
    end
  end
end
