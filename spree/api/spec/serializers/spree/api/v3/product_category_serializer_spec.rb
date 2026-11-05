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

  it 'still names both sides once the category has gone' do
    membership = product_category
    Spree::Category.where(id: category.id).delete_all

    payload = described_class.new(Spree::ProductCategory.new(
                                    id: membership.id, product_id: membership.product_id, category_id: membership.category_id
                                  )).to_h

    expect(payload['product_id']).to eq(product.prefixed_id)
    expect(payload['category_id']).to eq(category.prefixed_id)
  end

  it 'leaves an id nil when the column holds nothing' do
    payload = described_class.new(Spree::ProductCategory.new).to_h

    expect(payload['product_id']).to be_nil
    expect(payload['category_id']).to be_nil
  end
end
