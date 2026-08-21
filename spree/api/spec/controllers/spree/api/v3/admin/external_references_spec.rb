require 'spec_helper'

# The external-reference behaviour is one concern shared by every connector-facing
# admin controller, so it is proved once here against two controllers that reach
# persistence very differently: products write through a workflow, stock locations
# through the plain resource controller. A regression in either shape shows up here.
RSpec.describe 'Admin API external references', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe Spree::Api::V3::Admin::ProductsController do
    let!(:product) { create(:product, store: store, name: 'Widget') }

    it 'records the identity a connector sends when creating' do
      post :create, params: { name: 'Synced Widget',
                              external_references: [{ system: 'pim', external_id: 'SKU-1' }] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['external_references']).to eq('pim' => 'SKU-1')
    end

    # Products create through a workflow, not build_resource — the path where
    # a re-sent feed row used to persist a duplicate and then 422 writing the
    # reference.
    it 'updates the existing product when the feed re-sends a known key' do
      product.set_external_id('pim', 'SKU-1')

      expect do
        post :create, params: { name: 'Widget Renamed',
                                external_references: [{ system: 'pim', external_id: 'SKU-1' }] }, as: :json
      end.not_to change(Spree::Product, :count)

      expect(response).to have_http_status(:ok)
      expect(product.reload.name).to eq('Widget Renamed')
    end

    it 'keeps one product identifiable in two systems at once' do
      product.set_external_id('pim', 'SKU-1')

      patch :update, params: { id: product.prefixed_id,
                               external_references: [{ system: 'erp', external_id: 'MAT-100' }] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['external_references']).to eq('pim' => 'SKU-1', 'erp' => 'MAT-100')
    end

    # Read and write shapes match: a client can PATCH back exactly what it read.
    it 'accepts the same map shape it renders' do
      patch :update, params: { id: product.prefixed_id,
                               external_references: { erp: 'MAT-100', pim: 'SKU-1' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['external_references']).to eq('erp' => 'MAT-100', 'pim' => 'SKU-1')
    end

    it 'addresses a product by its external identity' do
      product.set_external_id('erp', 'MAT-100')

      patch :update, params: { id: 'external:erp:MAT-100', name: 'Renamed By ERP' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.name).to eq('Renamed By ERP')
    end

    it 'does not reach a product in another store through its external id' do
      elsewhere = create(:product, store: create(:store))
      elsewhere.set_external_id('erp', 'MAT-999')

      patch :update, params: { id: 'external:erp:MAT-999', name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(elsewhere.reload.name).not_to eq('Hijacked')
    end

    it 'still resolves a prefixed id when no external identity is used' do
      patch :update, params: { id: product.prefixed_id, name: 'Renamed Normally' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(product.reload.name).to eq('Renamed Normally')
    end
  end

  describe Spree::Api::V3::Admin::StockLocationsController do
    let!(:stock_location) { create(:stock_location, store: store, name: 'Main') }

    it 'upserts rather than duplicating when the feed re-sends a known id' do
      stock_location.set_external_id('erp', 'WH-1')

      expect do
        post :create, params: { name: 'Main Renamed',
                                external_references: [{ system: 'erp', external_id: 'WH-1' }] }, as: :json
      end.not_to change(Spree::StockLocation, :count)

      expect(stock_location.reload.name).to eq('Main Renamed')
    end

    it 'creates a new record when the external id is unknown' do
      expect do
        post :create, params: { name: 'Second Warehouse',
                                external_references: [{ system: 'erp', external_id: 'WH-2' }] }, as: :json
      end.to change(Spree::StockLocation, :count).by(1)

      expect(Spree::StockLocation.find_by_external_id('erp', 'WH-2')).to be_present
    end

    it 'does not treat another store external id as a match, so the feed creates its own row' do
      other_store = create(:store)
      create(:stock_location, store: other_store).set_external_id('erp', 'WH-9')

      expect do
        post :create, params: { name: 'Ours', external_references: [{ system: 'erp', external_id: 'WH-9' }] }, as: :json
      end.to change { store.stock_locations.count }.by(1)

      expect(store.stock_locations.find_by_external_id('erp', 'WH-9').name).to eq('Ours')
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  # An ERP that pushed its own order number wants to read the order back by
  # it; OrdersController resolves its resource itself, so this proves the
  # external addressing survives that override.
  it 'reaches an order by the number an external system pushed onto it' do
    order = create(:completed_order_with_totals, store: store)
    order.set_external_id('erp', 'SO-8812')

    get :show, params: { id: 'external:erp:SO-8812' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['id']).to eq(order.prefixed_id)
  end
end

RSpec.describe Spree::Api::V3::Admin::OrdersController, 'upsert by external id', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  # A replayed feed row must keep the address it sent rather than having it
  # dropped on the way through the update action. Create and update now name
  # addresses identically, so this guards against them diverging again.
  it 'keeps an address the create payload names when the feed replays a known key' do
    order = create(:order, store: store)
    order.set_external_id('erp', 'SO-1')

    expect do
      post :create, params: {
        email: 'buyer@example.com',
        shipping_address: { firstname: 'Ada', lastname: 'Lovelace', address1: '1 Main St',
                            city: 'New York', zipcode: '10001', phone: '555-0100',
                            country_code: 'US', state_code: 'NY' },
        external_references: [{ system: 'erp', external_id: 'SO-1' }]
      }, as: :json
    end.not_to change(Spree::Order, :count)

    expect(response).to have_http_status(:ok)
    expect(order.reload.email).to eq('buyer@example.com')
    expect(order.ship_address&.address1).to eq('1 Main St')
  end
end

RSpec.describe Spree::Api::V3::Admin::MediaController, 'upsert by external id', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }

  before { request.headers.merge!(headers) }

  # `url` and `signed_id` say how to fetch the bytes; neither is an attribute
  # on the row. A DAM re-posting an asset it already synced must not have them
  # reinterpreted as attributes by the update action.
  it 'accepts a replay carrying the create payload\'s fetch keys' do
    media = create(:image, viewable: product)
    media.set_external_id('dam', 'ASSET-1')

    expect do
      post :create, params: {
        product_id: product.prefixed_id,
        url: 'https://dam.example.com/asset-1.jpg',
        alt: 'A widget',
        external_references: { dam: 'ASSET-1' }
      }, as: :json
    end.not_to change(Spree::Media, :count)

    expect(response).to have_http_status(:ok)
    expect(media.reload.alt).to eq('A widget')
  end
end

RSpec.describe Spree::Api::V3::Admin::CategoriesController, 'conflicting external id', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  it 'reports a key that already names another record rather than raising' do
    taken = create(:category)
    taken.set_external_id('pim', 'CAT-1')

    patch :update, params: {
      id: create(:category).prefixed_id,
      external_references: { pim: 'CAT-1' }
    }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['code']).to eq('conflicting_external_reference')
  end
end

RSpec.describe Spree::Api::V3::Admin::CompanyLocationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  it 'records the identity a connector sends for a branch' do
    location = create(:company_location, company: create(:company, store: store))

    patch :update, params: { id: location.prefixed_id,
                             external_references: { crm: 'LOC-1' } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(location.reload.external_id_for('crm')).to eq('LOC-1')
  end
end
