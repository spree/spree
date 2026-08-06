require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxRatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:tax_category) { create(:tax_category) }
  let!(:zone) { create(:zone, kind: 'country') }
  let!(:tax_rate) { create(:tax_rate, tax_category: tax_category, zone: zone, amount: 0.19, included_in_price: true) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the rates of the current store only' do
      other_store_rate = create(:tax_rate, store: create(:store))

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |rate| rate['id'] }
      expect(ids).to include(tax_rate.prefixed_id)
      expect(ids).not_to include(other_store_rate.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the rate with its percentage and associations' do
      get :show, params: { id: tax_rate.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(tax_rate.prefixed_id)
      expect(json_response['amount']).to eq('0.19')
      expect(json_response['amount_percentage']).to eq(19.0)
      expect(json_response['included_in_price']).to be(true)
      expect(json_response['tax_category_id']).to eq(tax_category.prefixed_id)
      expect(json_response['zone_id']).to eq(zone.prefixed_id)
      expect(json_response['store_id']).to eq(@default_store.prefixed_id)
    end
  end

  describe 'POST #create' do
    let(:create_params) do
      { name: 'German VAT', amount: 0.19, included_in_price: true,
        tax_category_id: tax_category.prefixed_id, zone_id: zone.prefixed_id }
    end

    it 'creates a rate bound to the current store' do
      expect { post :create, params: create_params, as: :json }.to change(Spree::TaxRate, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('tax_')
      expect(Spree::TaxRate.last.store).to eq(@default_store)
    end

    it 'accepts a percentage instead of a decimal' do
      post :create, params: create_params.merge(amount: nil, amount_percentage: 7), as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::TaxRate.last.amount).to eq(0.07)
    end

    it 'rejects a rate with no category' do
      post :create, params: create_params.except(:tax_category_id), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates the rate' do
      patch :update, params: { id: tax_rate.prefixed_id, amount: 0 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(tax_rate.reload.amount).to eq(0)
    end

    it 'cannot move a rate to another store' do
      other_store = create(:store)

      patch :update, params: { id: tax_rate.prefixed_id, store_id: other_store.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(tax_rate.reload.store).to eq(@default_store)
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the rate' do
      delete :destroy, params: { id: tax_rate.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(tax_rate.reload.deleted_at).to be_present
    end
  end
end
