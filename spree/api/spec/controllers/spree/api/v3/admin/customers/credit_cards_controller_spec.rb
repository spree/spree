require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Customers::CreditCardsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user) }
  let(:payment_method) { create(:credit_card_payment_method) }
  let!(:credit_card) { create(:credit_card, user: customer, payment_method: payment_method) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the customer credit cards' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |c| c['id'] }).to include(credit_card.prefixed_id)
    end

    context 'when customer has no cards' do
      let(:customer) { create(:user) }
      let!(:credit_card) { nil }

      it 'returns an empty array' do
        get :index, params: { customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to eq([])
      end
    end

    context 'when customer does not exist' do
      it 'returns 404' do
        get :index, params: { customer_id: 'cus_unknown' }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the credit card' do
      get :show, params: { customer_id: customer.prefixed_id, id: credit_card.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(credit_card.prefixed_id)
    end

    context 'when card belongs to a different customer (security check)' do
      let(:other_customer) { create(:user) }
      let!(:other_card) { create(:credit_card, user: other_customer, payment_method: payment_method) }

      it 'returns 404 — cannot read another customer\'s cards' do
        get :show, params: { customer_id: customer.prefixed_id, id: other_card.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
