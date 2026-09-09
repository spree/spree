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

      expect(json_response['data'].first).not_to have_key('catalog_variants')
    end

    # The terms ride along on the rows they belong to. They used to be their
    # own unpaginated request that loaded every rule in the catalog and
    # grouped it by product — the same roll-up, over the variants this page
    # already holds (docs/plans/6.0-volume-pricing.md).
    it 'rolls a product\'s quantity terms up onto its row' do
      product = create(:product, store: store)
      create(:catalog_product, catalog: catalog, product: product)
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant,
                                     minimum_order_quantity: 48, order_multiple: 24)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'quantity_rule' }, as: :json

      rule = json_response['data'].first['quantity_rule']
      expect(rule['product_id']).to eq(product.prefixed_id)
      expect(rule['minimum_order_quantity']).to eq(48)
      expect(rule['order_multiple']).to eq(24)
    end

    # The rows are per variant, so a product whose variants disagree is
    # reported honestly rather than by picking one of them.
    it 'marks a product whose variants carry different terms as mixed' do
      product = create(:product, store: store)
      second = create(:variant, product: product)
      create(:catalog_product, catalog: catalog, product: product)
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant,
                                     minimum_order_quantity: 48)
      create(:catalog_quantity_rule, catalog: catalog, variant: second, minimum_order_quantity: 96)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'quantity_rule' }, as: :json

      expect(json_response['data'].first['quantity_rule']['mixed']).to be(true)
    end

    it 'leaves the terms out unless they are asked for' do
      product = create(:product, store: store)
      create(:catalog_product, catalog: catalog, product: product)
      create(:catalog_quantity_rule, catalog: catalog, variant: product.default_variant,
                                     minimum_order_quantity: 48)

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(json_response['data'].first).not_to have_key('quantity_rule')
    end

    # The card renders a name and a thumbnail, and the picker reads ids. A
    # full product payload per row is what made this page slow, so the shape
    # is pinned rather than left to whatever the admin serializer grows
    # (docs/plans/6.0-volume-pricing.md).
    it 'sends only what the membership card and the picker read' do
      create(:catalog_product, catalog: catalog, product: create(:product, store: store, price: 100))

      get :index, params: { catalog_id: catalog.prefixed_id }, as: :json

      expect(json_response['data'].first.keys).to match_array(%w[id name thumbnail_url])
    end

    it 'adds only the price reading when expanded' do
      create(:catalog_product, catalog: catalog, product: create(:product, store: store, price: 100))

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price' }, as: :json

      expect(json_response['data'].first.keys).
        to match_array(%w[id name thumbnail_url catalog_variants])
    end

    # What the products-with-prices view reads: the amount a buyer on this
    # agreement pays, and where it came from
    # (docs/plans/6.0-catalog-agreement-rework.md).
    it 'reports an amount derived from the catalog percentage' do
      product = create(:product, store: store, price: 100)
      create(:catalog_product, catalog: catalog, product: product)
      create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -15)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price' }, as: :json

      price = json_response['data'].first['catalog_variants'].first
      expect(price['amount']).to eq('85.0')
      expect(price['source']).to eq('automatic')
    end

    # The serializer matches dot notation, so the controller has to as well —
    # a stricter gate renders the attribute with no resolver behind it, and
    # every row reads as unpriced.
    it 'still resolves when the expand carries a nested path' do
      product = create(:product, store: store, price: 100)
      create(:catalog_product, catalog: catalog, product: product)
      create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -15)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price.anything' },
                  as: :json

      expect(json_response['data'].first['catalog_variants']).to be_present
    end

    # The divergence the view exists to expose: in the assortment, priced by
    # nothing the agreement says.
    it 'reports a product the agreement does not price as base' do
      product = create(:product, store: store, price: 100)
      create(:catalog_product, catalog: catalog, product: product)
      create(:price_list, :active, store: store, catalog: catalog)

      get :index, params: { catalog_id: catalog.prefixed_id, expand: 'catalog_price' }, as: :json

      expect(json_response['data'].first['catalog_variants'].first['source']).to eq('base')
    end
  end
end
