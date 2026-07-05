require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OptionTypesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:option_type) { create(:option_type) }
  let!(:option_value_1) { create(:option_value, option_type: option_type, position: 1) }
  let!(:option_value_2) { create(:option_value, option_type: option_type, position: 2) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns option types with nested option values when expanded' do
      get :index, params: { expand: 'option_values' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)

      ot = json_response['data'].find { |o| o['id'] == option_type.prefixed_id }
      expect(ot['name']).to eq(option_type.name)
      expect(ot['option_values']).to be_an(Array)
      expect(ot['option_values'].length).to eq(2)
    end
  end

  describe 'GET #show' do
    it 'returns the option type with option values when expanded' do
      get :show, params: { id: option_type.prefixed_id, expand: 'option_values' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(option_type.prefixed_id)
      expect(json_response['option_values'].length).to eq(2)
    end
  end

  describe 'POST #create' do
    it 'creates an option type with nested option values' do
      expect {
        post :create, params: {
          name: 'material',
          label: 'Material',
          expand: 'option_values',
          option_values: [
            { name: 'cotton', label: 'Cotton', position: 1 },
            { name: 'silk', label: 'Silk', position: 2 }
          ]
        }, as: :json
      }.to change(Spree::OptionType, :count).by(1)
       .and change(Spree::OptionValue, :count).by(2)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('material')
      expect(json_response['option_values'].length).to eq(2)
      expect(json_response['option_values'].map { |v| v['name'] }).to match_array(%w[cotton silk])
    end

    it 'creates an option type without option values' do
      expect {
        post :create, params: { name: 'size', label: 'Size' }, as: :json
      }.to change(Spree::OptionType, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('size')
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post :create, params: { name: '', label: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end

      it 'returns 422 (not 500) when a nested option_value is invalid' do
        post :create, params: {
          name: 'material',
          label: 'Material',
          option_values: [{ name: '', label: '' }]
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
        # Pin that this exercises the *nested* validation path: parent fields
        # are valid (`name`/`label` set), and the failure surfaces under the
        # autosave key for the child association — not on a top-level parent
        # attribute. Without this check the test could pass via the parent's
        # own `validates :presentation` if a future rename silently filtered
        # `label` from `permitted_params`.
        expect(json_response['error']['details'].keys).to include('option_values.name')
        expect(Spree::OptionType.where(name: 'material')).to be_empty
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates option type and syncs option values' do
      patch :update, params: {
        id: option_type.prefixed_id,
        label: 'Updated Label',
        expand: 'option_values',
        option_values: [
          { id: option_value_1.prefixed_id, name: option_value_1.name, label: 'Updated Value 1', position: 1 },
          { name: 'new-value', label: 'New Value', position: 2 }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['label']).to eq('Updated Label')
      expect(json_response['option_values'].length).to eq(2)

      # option_value_2 was not in the payload, so it should be deleted
      expect(Spree::OptionValue.find_by(id: option_value_2.id)).to be_nil
    end

    it 'updates option type without touching option values' do
      patch :update, params: {
        id: option_type.prefixed_id,
        label: 'Just Label'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(option_type.reload.option_values.count).to eq(2)
    end

    it 'returns 422 (not 500) when a nested option_value is invalid' do
      original_presentation = option_type.presentation

      patch :update, params: {
        id: option_type.prefixed_id,
        label: 'Updated',
        # `color_code` must be a valid hex; `not-a-hex` trips the format validator
        # so we exercise the nested-validation path without depending on which
        # presence rules normalize / backfill which fields.
        option_values: [{ id: option_value_1.prefixed_id, color_code: 'not-a-hex' }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
      # Pin that the failure comes from the nested record (autosave-style key)
      # rather than from a top-level parent attribute.
      expect(json_response['error']['details'].keys).to include('option_values.color_code')
      # Parent attribute change must roll back when option_values validation fails.
      expect(option_type.reload.presentation).to eq(original_presentation)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the option type' do
      expect {
        delete :destroy, params: { id: option_type.prefixed_id }, as: :json
      }.to change(Spree::OptionType, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
