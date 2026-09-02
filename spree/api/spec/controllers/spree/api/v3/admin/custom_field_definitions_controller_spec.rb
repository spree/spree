require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomFieldDefinitionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product_definition) do
    create(:custom_field_definition, :short_text_field, namespace: 'specs', key: 'fabric')
  end
  let!(:order_definition) { create(:custom_field_definition, :for_order) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns all definitions across resource types' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      keys = json_response['data'].map { |d| d['key'] }
      expect(keys).to include('fabric', order_definition.key)
    end

    it 'filters by resource_type via Ransack' do
      get :index, params: { q: { resource_type_eq: 'Spree::Product' } }, as: :json

      expect(response).to have_http_status(:ok)
      types = json_response['data'].map { |d| d['resource_type'] }.uniq
      expect(types).to eq(['Spree::Product'])
    end

    it 'exposes computed fields with their API names' do
      get :index, params: { q: { key_eq: 'fabric' } }, as: :json

      expect(response).to have_http_status(:ok)
      item = json_response['data'].find { |d| d['key'] == 'fabric' }
      expect(item).to include(
        'namespace' => 'specs',
        'field_type' => 'short_text',
        'storefront_visible' => true,
        'searchable' => false,
        'sortable' => false,
        'filter_key' => 'cf_specs_fabric'
      )
    end
  end

  describe 'POST #create' do
    let(:create_params) do
      {
        namespace: 'specs',
        key: 'origin',
        label: 'Country of Origin',
        field_type: 'short_text',
        resource_type: 'Spree::Product',
        storefront_visible: true
      }
    end

    it 'creates a definition' do
      expect { post :create, params: create_params, as: :json }.
        to change(Spree::CustomFieldDefinition, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['key']).to eq('origin')
      expect(json_response['label']).to eq('Country of Origin')
      expect(json_response['field_type']).to eq('short_text')
      expect(json_response['storefront_visible']).to eq(true)
      expect(json_response['searchable']).to eq(false)
      expect(json_response['sortable']).to eq(false)
    end

    it 'persists searchable and sortable flags' do
      post :create, params: create_params.merge(searchable: true, sortable: true, key: 'material'), as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['searchable']).to eq(true)
      expect(json_response['sortable']).to eq(true)

      defn = Spree::CustomFieldDefinition.find_by_prefix_id(json_response['id'])
      expect(defn.searchable).to eq(true)
      expect(defn.sortable).to eq(true)
    end

    context 'with storefront_visible: false' do
      it 'persists storefront_visible as false' do
        post :create, params: create_params.merge(storefront_visible: false), as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['storefront_visible']).to eq(false)

        defn = Spree::CustomFieldDefinition.find_by_prefix_id(json_response['id'])
        expect(defn.storefront_visible).to be(false)
      end
    end

    context 'when key collides with an existing definition for the same resource type' do
      it 'returns 422' do
        post :create, params: create_params.merge(key: 'fabric'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when field_type is not a registered type' do
      it 'returns 422' do
        post :create, params: create_params.merge(field_type: 'Spree::CustomFields::FakeKind'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when resource_type is not registered' do
      it 'returns 422' do
        post :create, params: create_params.merge(resource_type: 'Spree::Sasquatch'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when label is omitted' do
      it 'derives the name from the titleized key' do
        post :create, params: create_params.except(:label), as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['label']).to eq('Origin')
      end
    end

    it 'silently drops the legacy `metafield_type` param' do
      # `metafield_type` was never an API key and is not permitted; sending one
      # is ignored, leaving the default type in place.
      post :create,
           params: create_params.merge(metafield_type: 'Spree::CustomFields::Number'),
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['field_type']).to eq('short_text')
    end

    it 'accepts the legacy class-name form on `field_type` writes' do
      # Back-compat: external integrations that wrote `Spree::CustomFields::*`
      # under the old API contract keep working. Writes are translated; reads
      # always emit the token form.
      post :create,
           params: create_params.merge(field_type: 'Spree::CustomFields::Number', key: 'priority'),
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['field_type']).to eq('number')
    end
  end

  describe 'PATCH #update' do
    it "updates the definition's label and visibility" do
      patch :update,
            params: {
              id: product_definition.prefixed_id,
              label: 'Fabric Composition',
              storefront_visible: false
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['label']).to eq('Fabric Composition')
      expect(json_response['storefront_visible']).to eq(false)
      expect(product_definition.reload.storefront_visible).to be(false)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the definition and cascades to its custom fields' do
      product = create(:product)
      create(:custom_field, resource: product, custom_field_definition: product_definition, value: 'wool')

      delete :destroy, params: { id: product_definition.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CustomFieldDefinition.where(id: product_definition.id)).to be_empty
      expect(Spree::CustomField.where(custom_field_definition_id: product_definition.id)).to be_empty
    end
  end

  # Definitions are store-owned, so another store's schema is not readable,
  # editable or deletable through this endpoint — a cross-store id is simply
  # not found.
  describe 'store isolation' do
    let!(:other_store_definition) do
      create(:custom_field_definition, store: create(:store), namespace: 'specs', key: 'supplier')
    end

    it 'omits another store\'s definitions from the listing' do
      get :index, as: :json

      keys = json_response['data'].map { |definition| definition['key'] }
      expect(keys).to include('fabric')
      expect(keys).not_to include('supplier')
    end

    it 'does not find another store\'s definition' do
      get :show, params: { id: other_store_definition.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses to update another store\'s definition' do
      patch :update, params: { id: other_store_definition.prefixed_id, label: 'Taken' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_store_definition.reload.label).not_to eq('Taken')
    end

    it 'refuses to destroy another store\'s definition' do
      delete :destroy, params: { id: other_store_definition.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_store_definition.reload).to be_present
    end

    it 'builds a created definition on the requesting store' do
      post :create,
           params: { namespace: 'specs', key: 'weave', field_type: 'short_text', resource_type: 'Spree::Product' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(store.custom_field_definitions.find_by(key: 'weave')).to be_present
    end
  end

  describe 'API key scope enforcement' do
    let(:api_key) { create(:api_key, :secret, store: store, scopes: [granted_scope]) }
    let(:api_key_headers) { { 'x-spree-api-key' => api_key.plaintext_token } }
    let(:headers) { api_key_headers }

    context 'with read_settings' do
      let(:granted_scope) { 'read_settings' }

      it 'allows index' do
        get :index, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'rejects writes' do
        post :create, params: { namespace: 'x', key: 'y', field_type: 'short_text', resource_type: 'Spree::Product' }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with no relevant scope' do
      let(:granted_scope) { 'read_orders' }

      it 'rejects index with 403' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #resource_types' do
    it 'offers everything the registry allows, not a list the dashboard carries' do
      get :resource_types, as: :json

      expect(response).to have_http_status(:ok)
      types = json_response['data']
      values = types.map { |t| t['resource_type'] }

      # A resource is offered because core registered it — sellers included,
      # which is what a marketplace needs to ask for a VAT number.
      expect(values).to include('Spree::Seller', 'Spree::Product', 'Spree::Order')
      expect(values.size).to be > 6
    end

    it 'names categories as a merchant does while storing them where they live' do
      get :resource_types, as: :json

      category = json_response['data'].find { |t| t['resource_type'] == 'Spree::Taxon' }

      # The label follows the class a merchant knows; the value follows where
      # existing definitions are actually filed.
      expect(category['name']).to eq('Categories')
      expect(json_response['data'].map { |t| t['resource_type'] }).not_to include('Spree::Category')
    end

    it 'accepts the category type it offers, which is stored under the old class name' do
      get :resource_types, as: :json
      category = json_response['data'].find { |t| t['name'] == 'Categories' }

      post :create, params: {
        namespace: 'merch', key: 'aisle', label: 'Aisle',
        field_type: 'Spree::CustomFields::ShortText',
        resource_type: category['resource_type']
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['resource_type']).to eq('Spree::Taxon')
    end

    it 'accepts a type it offered' do
      get :resource_types, as: :json
      seller_type = json_response['data'].find { |t| t['resource_type'] == 'Spree::Seller' }

      post :create, params: {
        namespace: 'compliance', key: 'vat_number', label: 'VAT number',
        field_type: 'Spree::CustomFields::ShortText',
        resource_type: seller_type['resource_type']
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['resource_type']).to eq('Spree::Seller')
    end
  end

end
