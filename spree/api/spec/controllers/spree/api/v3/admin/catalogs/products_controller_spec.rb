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

    it 'leaves the resolved price out unless it is asked for' do
      create(:catalog_product, catalog: catalog, product: create(:product, store: store, price: 100))

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(json_response['data'].first).not_to have_key('catalog_price')
    end

    # What the products-with-prices view reads: the amount a buyer on this
    # agreement pays, and where it came from
    # (docs/plans/6.0-catalog-agreement-rework.md).
    it 'reports an amount derived from the catalog percentage' do
      product = create(:product, store: store, price: 100)
      create(:catalog_product, catalog: catalog, product: product)
      create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -15)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price' }, as: :json

      price = json_response['data'].first['catalog_price']
      expect(price['amount']).to eq('85.0')
      expect(price['source']).to eq('automatic')
    end

    # The divergence the view exists to expose: in the assortment, priced by
    # nothing the agreement says.
    it 'reports a product the agreement does not price as base' do
      product = create(:product, store: store, price: 100)
      create(:catalog_product, catalog: catalog, product: product)
      create(:price_list, :active, store: store, catalog: catalog)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price' }, as: :json

      expect(json_response['data'].first['catalog_price']['source']).to eq('base')
    end
  end
end
