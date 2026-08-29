require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Categories::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:category) { create(:category, name: 'Clothing', store: store) }

  before { request.headers.merge!(headers) }

  def classified_ids
    Spree::ProductCategory.where(category_id: category.id).order(:position).pluck(:product_id)
  end

  describe 'GET #index' do
    let!(:product_a) { create(:product, store: store) }
    let!(:product_b) { create(:product, store: store) }
    let!(:product_c) { create(:product, store: store) }
    let!(:other_category_product) { create(:product, store: store) }
    let!(:other_category) { create(:category, name: 'Other', store: store) }

    before do
      create(:product_category, category: category, product: product_b, position: 1)
      create(:product_category, category: category, product: product_a, position: 2)
      create(:product_category, category: category, product: product_c, position: 3)
      # A product in a different category must not leak into this list.
      create(:product_category, category: other_category, product: other_category_product, position: 1)
    end

    it 'lists only the category products, ordered by classification position' do
      get :index, params: { category_id: category.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      # Ordered by position (b, a, c) — a DISTINCT/ORDER-BY mismatch on Postgres
      # would 500 here, so this exercises the ordered, deduplicated collection.
      expect(ids).to eq([product_b.prefixed_id, product_a.prefixed_id, product_c.prefixed_id])
      expect(ids).not_to include(other_category_product.prefixed_id)
    end

    it 'returns an empty list for a category with no products' do
      empty = create(:category, name: 'Empty', store: store)
      get :index, params: { category_id: empty.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end
  end

  it_behaves_like 'a product membership surface' do
    let(:parent_route_params) { { category_id: category.prefixed_id } }
    let(:foreign_parent_route_params) do
      { category_id: create(:category, store: create(:store)).prefixed_id }
    end

    def seed_member(product)
      Spree::Categories::AddProducts.call(categories: [category], products: [product])
    end

    def member_products
      category.products.reload.to_a
    end
  end

  describe 'PATCH #reposition' do
    let!(:first)  { create(:product, store: store) }
    let!(:second) { create(:product, store: store) }
    let!(:third)  { create(:product, store: store) }

    before do
      create(:product_category, category: category, product: first, position: 1)
      create(:product_category, category: category, product: second, position: 2)
      create(:product_category, category: category, product: third, position: 3)
    end

    it 'moves a product to the requested index' do
      patch :reposition, params: { category_id: category.prefixed_id, id: third.prefixed_id, new_position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(classified_ids).to eq([third.id, first.id, second.id])
    end

    it 'returns 422 for a missing new_position' do
      patch :reposition, params: { category_id: category.prefixed_id, id: third.prefixed_id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for a non-integer new_position' do
      patch :reposition, params: { category_id: category.prefixed_id, id: third.prefixed_id, new_position: 'abc' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
