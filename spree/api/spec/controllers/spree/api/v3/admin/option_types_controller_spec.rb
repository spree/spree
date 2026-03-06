require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OptionTypesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:option_type) { create(:option_type) }
  let!(:option_value_1) { create(:option_value, option_type: option_type, position: 1) }
  let!(:option_value_2) { create(:option_value, option_type: option_type, position: 2) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns option types with nested option values' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)

      ot = json_response['data'].find { |o| o['id'] == option_type.prefixed_id }
      expect(ot['name']).to eq(option_type.name)
      expect(ot['option_values']).to be_an(Array)
      expect(ot['option_values'].length).to eq(2)
    end
  end

  describe 'GET #show' do
    it 'returns the option type with option values' do
      get :show, params: { id: option_type.prefixed_id }, as: :json

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
          presentation: 'Material',
          option_values: [
            { name: 'cotton', presentation: 'Cotton', position: 1 },
            { name: 'silk', presentation: 'Silk', position: 2 }
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
        post :create, params: { name: 'size', presentation: 'Size' }, as: :json
      }.to change(Spree::OptionType, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('size')
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post :create, params: { name: '', presentation: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates option type and syncs option values' do
      patch :update, params: {
        id: option_type.prefixed_id,
        presentation: 'Updated Presentation',
        option_values: [
          { id: option_value_1.prefixed_id, name: option_value_1.name, presentation: 'Updated Value 1', position: 1 },
          { name: 'new-value', presentation: 'New Value', position: 2 }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['presentation']).to eq('Updated Presentation')
      expect(json_response['option_values'].length).to eq(2)

      # option_value_2 was not in the payload, so it should be deleted
      expect(Spree::OptionValue.find_by(id: option_value_2.id)).to be_nil
    end

    it 'updates option type without touching option values' do
      patch :update, params: {
        id: option_type.prefixed_id,
        presentation: 'Just Presentation'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(option_type.reload.option_values.count).to eq(2)
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
