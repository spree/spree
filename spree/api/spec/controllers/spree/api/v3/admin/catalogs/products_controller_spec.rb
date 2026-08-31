require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Catalogs::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store) }

  before { request.headers.merge!(headers) }

  it_behaves_like 'a product membership surface' do
    let(:parent_route_params) { { catalog_id: catalog.prefixed_id } }
    let(:foreign_parent_route_params) do
      { catalog_id: create(:catalog, store: create(:store)).prefixed_id }
    end

    def seed_member(product)
      catalog.add_products([product.id])
    end

    def member_products
      catalog.products.reload.to_a
    end
  end

  describe 'GET #index' do
    it 'lists the assortment by name' do
      last = create(:catalog_product, catalog: catalog, product: create(:product, store: store, name: 'Zebra'))
      first = create(:catalog_product, catalog: catalog, product: create(:product, store: store, name: 'Aardvark'))

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).
        to eq([first.product.prefixed_id, last.product.prefixed_id])
    end
  end
end
