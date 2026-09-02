require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:customer) { create(:user, email: 'buyer@example.com', first_name: 'Ada') }

  before { request.headers.merge!(headers) }

  describe 'GET #export' do
    it 'returns the data the store holds about the customer' do
      get :export, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.dig('account', 'email')).to eq('buyer@example.com')
    end

    it 'includes the sections a subject access request has to answer' do
      get :export, params: { id: customer.prefixed_id }, as: :json

      expect(json_response.keys).to include('account', 'addresses', 'orders', 'marketing_consent', 'consent_records')
    end

    it '404s for a customer that does not exist' do
      get :export, params: { id: 'cust_nonexistent' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #anonymize' do
    it 'erases the customer' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer.reload.email).not_to eq('buyer@example.com')
      expect(customer.anonymized_at).to be_present
    end

    it 'reports the erasure in the response' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(json_response['anonymized']).to be(true)
    end

    it 'refuses a customer already erased' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'keeps a completed order the customer placed' do
      order = create(:completed_order_with_totals, customer: customer, store: store)

      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(order.reload).to be_persisted
      expect(order.total).to be_positive
    end
  end
end
