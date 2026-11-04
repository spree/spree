require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductCategorySerializer do
  let(:product) { create(:product) }
  let(:category) { create(:category) }
  let(:product_category) { Spree::ProductCategory.create!(product: product, category: category) }

  subject(:payload) { described_class.new(product_category).to_h }

  it 'names both sides of the membership by prefixed id' do
    expect(payload['product_id']).to eq(product.prefixed_id)
    expect(payload['category_id']).to eq(category.prefixed_id)
  end

  it 'identifies the membership itself' do
    expect(payload['id']).to eq(product_category.prefixed_id)
    expect(payload['id']).to start_with('pctg_')
  end
end
