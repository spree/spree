require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Categories::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:category) { Spree::Category.create!(name: 'Clothing', store: store) }

  before { request.headers.merge!(headers) }

  def classified_ids
    Spree::Classification.where(taxon_id: category.id).order(:position).pluck(:product_id)
  end

  describe 'GET #index' do
    let!(:product_a) { create(:product, stores: [store]) }
    let!(:product_b) { create(:product, stores: [store]) }
    let!(:product_c) { create(:product, stores: [store]) }
    let!(:other_category_product) { create(:product, stores: [store]) }
    let!(:other_category) { Spree::Category.create!(name: 'Other', store: store) }

    before do
      Spree::Classification.create!(taxon: category, product: product_b, position: 1)
      Spree::Classification.create!(taxon: category, product: product_a, position: 2)
      Spree::Classification.create!(taxon: category, product: product_c, position: 3)
      # A product in a different category must not leak into this list.
      Spree::Classification.create!(taxon: other_category, product: other_category_product, position: 1)
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
      empty = Spree::Category.create!(name: 'Empty', store: store)
      get :index, params: { category_id: empty.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end
  end

  describe 'POST #create' do
    let!(:product) { create(:product, stores: [store]) }

    it 'adds the product to the category' do
      post :create, params: { category_id: category.prefixed_id, product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(classified_ids).to include(product.id)
    end

    it '404s for a product outside the store' do
      other = create(:product, stores: [create(:store)])
      post :create, params: { category_id: category.prefixed_id, product_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    let!(:product) { create(:product, stores: [store]) }

    before { Spree::Classification.create!(taxon: category, product: product, position: 1) }

    it 'removes the product from the category' do
      delete :destroy, params: { category_id: category.prefixed_id, id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(classified_ids).not_to include(product.id)
    end

    it '404s for a product not in the category' do
      stray = create(:product, stores: [store])
      delete :destroy, params: { category_id: category.prefixed_id, id: stray.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #reposition' do
    let!(:first)  { create(:product, stores: [store]) }
    let!(:second) { create(:product, stores: [store]) }
    let!(:third)  { create(:product, stores: [store]) }

    before do
      Spree::Classification.create!(taxon: category, product: first, position: 1)
      Spree::Classification.create!(taxon: category, product: second, position: 2)
      Spree::Classification.create!(taxon: category, product: third, position: 3)
    end

    it 'moves a product to the requested index' do
      patch :reposition, params: { category_id: category.prefixed_id, id: third.prefixed_id, new_position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(classified_ids).to eq([third.id, first.id, second.id])
    end
  end
end
