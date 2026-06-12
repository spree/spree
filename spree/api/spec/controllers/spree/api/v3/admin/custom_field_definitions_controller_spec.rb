require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomFieldDefinitionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product_definition) do
    create(:metafield_definition, :short_text_field, namespace: 'specs', key: 'fabric')
  end
  let!(:order_definition) { create(:metafield_definition, :for_order) }

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
        'storefront_visible' => true
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
    end

    context 'with storefront_visible: false' do
      it 'maps to display_on: back_end internally' do
        post :create, params: create_params.merge(storefront_visible: false), as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['storefront_visible']).to eq(false)

        defn = Spree::CustomFieldDefinition.find_by_prefix_id(json_response['id'])
        expect(defn.display_on).to eq('back_end')
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
        post :create, params: create_params.merge(field_type: 'Spree::Metafields::FakeKind'), as: :json

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

    it 'silently drops `metafield_type` (no longer a permitted API param)' do
      # 5.4 leaks no `metafield_type` API key; sending one is ignored. The
      # `field_type` API param is the only way to set the column.
      post :create,
           params: create_params.merge(metafield_type: 'Spree::Metafields::Number'),
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['field_type']).to eq('short_text')
    end

    it 'accepts the legacy class-name form on `field_type` writes' do
      # Back-compat: external integrations that wrote `Spree::Metafields::*`
      # under the old API contract keep working. Writes are translated; reads
      # always emit the token form.
      post :create,
           params: create_params.merge(field_type: 'Spree::Metafields::Number', key: 'priority'),
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
      expect(product_definition.reload.display_on).to eq('back_end')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the definition and cascades to its custom fields' do
      product = create(:product)
      create(:metafield, resource: product, metafield_definition: product_definition, value: 'wool')

      delete :destroy, params: { id: product_definition.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CustomFieldDefinition.where(id: product_definition.id)).to be_empty
      expect(Spree::CustomField.where(custom_field_definition_id: product_definition.id)).to be_empty
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
end
