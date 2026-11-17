require 'spec_helper'

RSpec.describe Spree::CollectionExclusion, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:automatic_collection, store: store) }
  let(:product) { create(:product, store: store) }

  it 'removes the product from the collection, whatever its source' do
    create(:product_collection, collection: collection, product: product)

    create(:collection_exclusion, collection: collection, product: product)

    expect(collection.reload.products).to be_empty
    expect(collection.products_count).to eq(0)
  end

  it 'regenerates the collection when lifted' do
    create(:tag_collection_rule, collection: collection, value: 'sale')
    exclusion = create(:collection_exclusion, collection: collection, product: product)

    expect { exclusion.destroy! }.to have_enqueued_job(Spree::Collections::RegenerateProductsJob).with(collection.id)
  end

  it 'refuses a product of another store' do
    foreign = create(:product, store: create(:store))

    expect(build(:collection_exclusion, collection: collection, product: foreign)).not_to be_valid
  end
end
