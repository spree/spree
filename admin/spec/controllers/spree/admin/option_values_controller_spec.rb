require 'spec_helper'

RSpec.describe Spree::Admin::OptionValuesController do
  stub_authorization!

  render_views

  let(:option_type) { create(:option_type) }
  let(:option_value) { create(:option_value, option_type: option_type) }

  describe 'PATCH #update' do
    context 'with turbo_stream format' do
      let(:option_value_params) do
        {
          position: 2
        }
      end

      before do
        patch :update, params: {
          option_type_id: option_type.id,
          id: option_value.id,
          option_value: option_value_params,
          format: :turbo_stream
        }
      end

      it 'updates the option value' do
        option_value.reload
        expect(option_value.position).to eq(2)
      end

      it 'returns success status' do
        expect(response).to be_successful
      end
    end
  end

  describe 'GET #select_options' do
    before do
      option_value
      create_list(:option_value, 3, option_type: option_type)
      get :select_options, params: { option_type_id: option_type.id, format: :json }
    end

    it 'returns success status' do
      expect(response).to be_successful
    end

    it 'returns JSON format' do
      expect(response.content_type).to include('application/json')
    end

    it 'returns option values in tom select format' do
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first).to eq({
        id: option_value.name,
        name: option_value.presentation
      }.stringify_keys)
      expect(json_response.length).to eq(4)
    end
  end
end
