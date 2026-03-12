require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ShippingCategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:shipping_category) { create(:shipping_category) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns shipping categories' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |sc| sc['id'] }).to include(shipping_category.prefixed_id)
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: shipping_category.prefixed_id }, as: :json }

    it 'returns the shipping category' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(shipping_category.prefixed_id)
      expect(json_response['name']).to eq(shipping_category.name)
    end
  end
end
