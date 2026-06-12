require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomFieldsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:product) { create(:product) }
  let(:short_text_definition) { create(:metafield_definition, :short_text_field) }
  let(:long_text_definition) { create(:metafield_definition, :long_text_field) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:custom_field) do
      create(:metafield, resource: product, metafield_definition: short_text_definition, value: 'wool')
    end

    it 'returns the parent custom fields' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].first['custom_field_definition_id']).to eq(short_text_definition.prefixed_id)
      expect(json_response['data'].first['value']).to eq('wool')
    end

    it 'returns 404 when the parent product does not exist' do
      get :index, params: { product_id: 'prod_NotARealId' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'scopes the collection to the parent — sibling products are not returned' do
      other_product = create(:product)
      create(:metafield, resource: other_product, metafield_definition: long_text_definition,
                         type: 'Spree::Metafields::LongText', value: 'unrelated')

      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      values = json_response['data'].map { |cf| cf['value'] }
      expect(values).to contain_exactly('wool')
    end
  end

  describe 'POST #create' do
    let(:create_params) do
      {
        product_id: product.prefixed_id,
        custom_field_definition_id: short_text_definition.prefixed_id,
        value: 'wool'
      }
    end

    it 'creates a custom field on the parent' do
      expect { post :create, params: create_params, as: :json }.
        to change { product.metafields.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['value']).to eq('wool')
      expect(json_response['custom_field_definition_id']).to eq(short_text_definition.prefixed_id)
    end

    context 'when custom_field_definition_id is missing' do
      it 'returns 422' do
        post :create, params: create_params.except(:custom_field_definition_id), as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when value is missing' do
      it 'returns 422' do
        post :create, params: create_params.merge(value: ''), as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when a custom field for the same definition already exists' do
      before do
        create(:metafield, resource: product, metafield_definition: short_text_definition, value: 'cotton')
      end

      it 'returns 422 (uniqueness on definition + resource)' do
        post :create, params: create_params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the parent does not exist' do
      it 'returns 404' do
        post :create, params: create_params.merge(product_id: 'prod_NotARealId'), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:custom_field) do
      create(:metafield, resource: product, metafield_definition: short_text_definition, value: 'wool')
    end

    it "updates the custom field's value" do
      patch :update,
            params: { product_id: product.prefixed_id, id: custom_field.prefixed_id, value: 'cotton' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['value']).to eq('cotton')
      expect(custom_field.reload.value).to eq('cotton')
    end

    it 'ignores attempts to swap the linked definition' do
      patch :update,
            params: {
              product_id: product.prefixed_id,
              id: custom_field.prefixed_id,
              value: 'cotton',
              custom_field_definition_id: long_text_definition.prefixed_id
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(custom_field.reload.metafield_definition_id).to eq(short_text_definition.id)
    end

    it 'returns 404 when the custom field does not belong to the parent' do
      sibling = create(:product)
      foreign = create(:metafield, resource: sibling, metafield_definition: long_text_definition,
                                   type: 'Spree::Metafields::LongText', value: 'foreign')

      patch :update,
            params: { product_id: product.prefixed_id, id: foreign.prefixed_id, value: 'x' },
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    let!(:custom_field) do
      create(:metafield, resource: product, metafield_definition: short_text_definition, value: 'wool')
    end

    it 'destroys the custom field' do
      delete :destroy, params: { product_id: product.prefixed_id, id: custom_field.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CustomField.where(id: custom_field.id)).to be_empty
    end

    it 'does not destroy a custom field that belongs to a sibling parent' do
      sibling = create(:product)
      foreign = create(:metafield, resource: sibling, metafield_definition: long_text_definition,
                                   type: 'Spree::Metafields::LongText', value: 'foreign')

      delete :destroy, params: { product_id: product.prefixed_id, id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::CustomField.where(id: foreign.id)).to exist
    end
  end

  describe 'cross-store IDOR — a product in another store' do
    let(:other_store) { create(:store) }
    let(:other_product) { create(:product, store: other_store) }
    let!(:foreign_field) do
      create(:metafield, resource: other_product, metafield_definition: short_text_definition, value: 'secret')
    end

    it 'does not list custom fields of another store\'s product' do
      get :index, params: { product_id: other_product.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'does not create a custom field on another store\'s product' do
      expect {
        post :create,
             params: {
               product_id: other_product.prefixed_id,
               custom_field_definition_id: long_text_definition.prefixed_id,
               value: 'injected'
             },
             as: :json
      }.not_to change { other_product.metafields.count }

      expect(response).to have_http_status(:not_found)
    end

    it 'does not update a custom field on another store\'s product' do
      patch :update,
            params: { product_id: other_product.prefixed_id, id: foreign_field.prefixed_id, value: 'tampered' },
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign_field.reload.value).to eq('secret')
    end
  end

  describe 'API key scope enforcement' do
    let(:api_key) { create(:api_key, :secret, store: store, scopes: [granted_scope]) }
    let(:api_key_headers) { { 'x-spree-api-key' => api_key.plaintext_token } }
    let(:headers) { api_key_headers }

    context 'with a key that grants write_products' do
      let(:granted_scope) { 'write_products' }

      it 'allows creating a product custom field' do
        post :create,
             params: {
               product_id: product.prefixed_id,
               custom_field_definition_id: short_text_definition.prefixed_id,
               value: 'wool'
             },
             as: :json

        expect(response).to have_http_status(:created)
      end
    end

    context 'with a key that only grants read_products' do
      let(:granted_scope) { 'read_products' }

      it 'allows reading' do
        create(:metafield, resource: product, metafield_definition: short_text_definition, value: 'wool')

        get :index, params: { product_id: product.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'rejects writing with 403' do
        post :create,
             params: {
               product_id: product.prefixed_id,
               custom_field_definition_id: short_text_definition.prefixed_id,
               value: 'wool'
             },
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_products')
      end
    end

    context 'with a key that grants write_orders but not write_products' do
      let(:granted_scope) { 'write_orders' }

      it 'rejects with 403' do
        post :create,
             params: {
               product_id: product.prefixed_id,
               custom_field_definition_id: short_text_definition.prefixed_id,
               value: 'wool'
             },
             as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a variant parent' do
      # Regression: `variant` / `option_type` parents used to resolve to the
      # ungrantable scope names `variants` / `option_types`, locking these
      # endpoints to *_all keys. Both fold into `products` now.
      let(:granted_scope) { 'write_products' }
      let(:variant) { create(:variant) }
      let(:variant_definition) do
        create(:metafield_definition, :short_text_field, resource_type: 'Spree::Variant')
      end

      it 'allows creating a variant custom field with write_products' do
        post :create,
             params: {
               variant_id: variant.prefixed_id,
               custom_field_definition_id: variant_definition.prefixed_id,
               value: 'ribbed'
             },
             as: :json

        expect(response).to have_http_status(:created)
      end
    end
  end
end
