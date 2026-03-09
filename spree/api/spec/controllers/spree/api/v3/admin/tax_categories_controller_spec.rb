require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxCategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:tax_category) { create(:tax_category) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns tax categories' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |tc| tc['id'] }).to include(tax_category.prefixed_id)
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: tax_category.prefixed_id }, as: :json }

    it 'returns the tax category' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(tax_category.prefixed_id)
      expect(json_response['name']).to eq(tax_category.name)
    end
  end
end
