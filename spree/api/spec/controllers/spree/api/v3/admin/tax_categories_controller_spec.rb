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

  describe 'POST #create' do
    let(:create_params) { { name: 'Reduced Rate', tax_code: 'RR', description: 'Books, food, etc.' } }

    it 'creates a tax category' do
      expect { post :create, params: create_params, as: :json }.to change(Spree::TaxCategory, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Reduced Rate')
      expect(json_response['tax_code']).to eq('RR')
      expect(json_response['description']).to eq('Books, food, etc.')
    end

    it 'returns 422 when name is missing' do
      post :create, params: { tax_code: 'RR' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'demotes the previous default when is_default is true' do
      previous_default = create(:tax_category, is_default: true)

      post :create, params: create_params.merge(is_default: true), as: :json

      expect(response).to have_http_status(:created)
      expect(previous_default.reload.is_default).to be false
    end
  end

  describe 'PATCH #update' do
    it 'updates the tax category' do
      patch :update, params: { id: tax_category.prefixed_id, name: 'Updated' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(tax_category.reload.name).to eq('Updated')
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the tax category' do
      target = create(:tax_category)

      expect { delete :destroy, params: { id: target.prefixed_id }, as: :json }.
        to change { Spree::TaxCategory.where(id: target.id).count }.by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Spree::TaxCategory.with_deleted.exists?(id: target.id)).to be true
    end
  end
end
