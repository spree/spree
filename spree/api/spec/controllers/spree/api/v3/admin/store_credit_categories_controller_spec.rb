require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreCreditCategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:store_credit_category) { create(:store_credit_category) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns store credit categories' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |c| c['id'] }).to include(store_credit_category.prefixed_id)
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: store_credit_category.prefixed_id }, as: :json }

    it 'returns the store credit category' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store_credit_category.prefixed_id)
      expect(json_response['name']).to eq(store_credit_category.name)
      expect(json_response).to have_key('non_expiring')
    end
  end
end
