require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CatalogsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  before { request.headers.merge!(headers) }

  # Standing up an agreement is one request — the catalog and the list it
  # prices through (docs/plans/6.0-catalog-agreement-rework.md).
  it 'writes and returns the description' do
    patch :update, params: { id: catalog.prefixed_id, description: 'Negotiated 2026 terms' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['description']).to eq('Negotiated 2026 terms')
    expect(catalog.reload.description).to eq('Negotiated 2026 terms')
  end

  describe 'the inline price_list payload' do
    it 'creates the catalog and its owned list together' do
      post :create,
           params: {
             name: 'Wholesale tier',
             price_list: { price_adjustment_percentage: '-15.0' }
           },
           as: :json

      expect(response).to have_http_status(:created)

      created = store.catalogs.find_by(name: 'Wholesale tier')
      list = created.price_list
      expect(list).to be_present
      expect(list.price_adjustment_percentage).to eq(-15)
      # Named after the catalog, since a merchant never sees it separately.
      expect(list.name).to eq('Wholesale tier')
      # Born active: the catalog's own flag already gates the agreement.
      expect(list).to be_active
    end

    # A percentage plus a volume rule is an automatic volume discount, and
    # both halves have to be settable in the one request that stands the
    # agreement up (docs/plans/6.0-price-list-automatic-pricing.md).
    it 'accepts the contextual rules that make automatic volume pricing work' do
      post :create,
           params: {
             name: 'Bulk tier',
             price_list: {
               price_adjustment_percentage: '-10',
               rules: [{ type: 'volume_rule', preferences: { min_quantity: 10 } }]
             }
           },
           as: :json

      expect(response).to have_http_status(:created)

      list = store.catalogs.find_by(name: 'Bulk tier').price_list
      rule = list.price_rules.sole
      expect(rule).to be_a(Spree::PriceRules::VolumeRule)
      expect(rule.preferred_min_quantity).to eq(10)
    end

    # Switching to hand-entered prices has to take the threshold with it.
    # A rule left behind would gate the merchant's own amounts, and the card
    # stops showing the field, so nothing would explain the missing discount.
    it 'clears the volume rule when the agreement moves to fixed prices' do
      post :create,
           params: {
             name: 'Switcher',
             price_list: {
               price_adjustment_percentage: '-10',
               rules: [{ type: 'volume_rule', preferences: { min_quantity: 10 } }]
             }
           },
           as: :json
      created = store.catalogs.find_by(name: 'Switcher')
      expect(created.price_list.price_rules.count).to eq(1)

      patch :update,
            params: { id: created.prefixed_id,
                      price_list: { price_adjustment_percentage: nil, rules: [] } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(created.price_list.reload.price_rules).to be_empty
    end

    it 'updates the owned list in place' do
      post :create, params: { name: 'Tier', price_list: { price_adjustment_percentage: '-10' } }, as: :json
      created = store.catalogs.find_by(name: 'Tier')
      list_id = created.price_list.id

      patch :update,
            params: { id: created.prefixed_id, price_list: { price_adjustment_percentage: '-20' } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(created.reload.price_list.id).to eq(list_id)
      expect(created.price_list.price_adjustment_percentage).to eq(-20)
    end

    # A released list would price every shopper, since an owned list carries
    # no rules — so removal takes the list with it.
    it 'removes the owned list on an explicit null' do
      post :create, params: { name: 'Tier', price_list: { price_adjustment_percentage: '-10' } }, as: :json
      created = store.catalogs.find_by(name: 'Tier')
      list_id = created.price_list.id

      patch :update, params: { id: created.prefixed_id, price_list: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(created.reload.price_list).to be_nil
      expect(Spree::PriceList.where(id: list_id)).to be_empty
    end

    it 'leaves the list alone when the key is omitted' do
      post :create, params: { name: 'Tier', price_list: { price_adjustment_percentage: '-10' } }, as: :json
      created = store.catalogs.find_by(name: 'Tier')

      patch :update, params: { id: created.prefixed_id, name: 'Renamed' }, as: :json

      expect(created.reload.name).to eq('Renamed')
      expect(created.price_list).to be_present
    end

    it 'refuses an invalid adjustment without creating the catalog' do
      expect {
        post :create,
             params: { name: 'Bad tier', price_list: { price_adjustment_percentage: '-100' } },
             as: :json
      }.not_to change { store.catalogs.count }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'clears hand-entered amounts when the payload says to' do
      post :create, params: { name: 'Tier', price_list: { name: 'Fixed' } }, as: :json
      created = store.catalogs.find_by(name: 'Tier')
      variant = create(:variant)
      create(:price, variant: variant, currency: 'EUR', amount: 5, price_list: created.price_list)

      patch :update,
            params: { id: created.prefixed_id,
                      price_list: { price_adjustment_percentage: '-15', prices: [] } },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(created.reload.price_list.prices.first.amount).to be_nil
    end

    it 'expands the owned list on read' do
      post :create, params: { name: 'Tier', price_list: { price_adjustment_percentage: '-10' } }, as: :json
      created = store.catalogs.find_by(name: 'Tier')

      get :show, params: { id: created.prefixed_id, expand: 'price_list' }, as: :json

      expect(json_response['price_list']['price_adjustment_percentage']).to eq('-10.0')
    end
  end

  describe 'GET #index' do
    it 'lists the store catalogs with product counts' do
      create(:catalog_product, catalog: catalog)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cat_')
      expect(row['name']).to eq('Wholesale')
      expect(row['products_count']).to eq(1)
    end

    it 'hides catalogs belonging to another store' do
      other = create(:catalog, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'creates a catalog with a price list' do
      price_list = create(:price_list, store: store)

      post :create, params: { name: 'VIP', price_list_id: price_list.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['price_list_id']).to eq(price_list.prefixed_id)
    end

    it '404s a price list from another store' do
      foreign = create(:price_list, store: create(:store))

      post :create, params: { name: 'VIP', price_list_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #import_products' do
    it 'copies the price list products into the assortment' do
      product = create(:product, store: store, price: 100)
      price_list = create(:price_list, store: store).tap { |list| list.add_products([product.id]) }
      catalog.update!(price_list: price_list)

      post :import_products, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['added_count']).to eq(1)
      expect(catalog.products.reload).to contain_exactly(product)
    end

    it '422s without a price list' do
      post :import_products, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PUT #set_assignments' do
    let!(:company) { create(:company, store: store) }
    let!(:group) { create(:customer_group, store: store) }

    it 'writes the whole audience in one request' do
      put :set_assignments, params: {
        id: catalog.prefixed_id,
        assignments: [
          { assignable_type: 'company', assignable_id: company.prefixed_id },
          { assignable_type: 'customer_group', assignable_id: group.prefixed_id }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(catalog.catalog_assignments.reload.map(&:assignable)).to match_array([company, group])
    end

    # The set arrives whole, so an audience left out is one the merchant
    # removed on a page that stages every change behind its Save.
    it 'withdraws an audience the payload leaves out' do
      catalog.catalog_assignments.create!(assignable: company)
      catalog.catalog_assignments.create!(assignable: group)

      put :set_assignments, params: {
        id: catalog.prefixed_id,
        assignments: [{ assignable_type: 'company', assignable_id: company.prefixed_id }]
      }, as: :json

      expect(catalog.catalog_assignments.reload.map(&:assignable)).to eq([company])
    end

    it 'clears the audience for an empty payload' do
      catalog.catalog_assignments.create!(assignable: company)

      put :set_assignments, params: { id: catalog.prefixed_id, assignments: [] }, as: :json

      expect(catalog.catalog_assignments.reload).to be_empty
    end

    # A set write must not reach an audience the one-at-a-time path could not.
    it 'is not found for an audience in another store' do
      foreign = create(:company, store: create(:store))

      put :set_assignments, params: {
        id: catalog.prefixed_id,
        assignments: [{ assignable_type: 'company', assignable_id: foreign.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(catalog.catalog_assignments.reload).to be_empty
    end
  end

  describe 'POST #assign' do
    it 'assigns the catalog to a company node' do
      company = create(:company, store: store)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['assignable_type']).to eq('company')
      expect(json_response['assignable_id']).to eq(company.prefixed_id)
      expect(json_response['assignable_name']).to eq(company.name)
    end

    it 'assigns to a customer group' do
      group = create(:customer_group, store: store)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'customer_group', assignable_id: group.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
    end

    it '404s an audience from another store' do
      foreign = create(:company, store: create(:store))

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # Store scope is not enough: a role that cannot see a company must not be
    # able to assign a catalog to it, and not-found keeps its existence quiet.
    it '404s an audience the caller may not see' do
      company = create(:company, store: store)
      allow_any_instance_of(described_class).to receive(:current_ability).
        and_return(Spree::Ability.new(nil))

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s an unknown audience type' do
      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'order', assignable_id: 'x' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a duplicate assignment' do
      company = create(:company, store: store)
      create(:catalog_assignment, catalog: catalog, assignable: company)

      post :assign, params: { id: catalog.prefixed_id, assignable_type: 'company', assignable_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the catalog with its assortment and assignments' do
      create(:catalog_product, catalog: catalog)
      create(:catalog_assignment, catalog: catalog, assignable: create(:company, store: store))

      delete :destroy, params: { id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CatalogProduct.count).to eq(0)
      expect(Spree::CatalogAssignment.count).to eq(0)
    end
  end
end
