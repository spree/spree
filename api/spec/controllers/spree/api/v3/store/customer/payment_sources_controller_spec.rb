require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::PaymentSourcesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:credit_card) { create(:credit_card, user: user) }
  let!(:payment_source) { create(:wallet_payment_source, user: user, payment_source: credit_card) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns the user wallet payment sources' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(user.wallet_payment_sources.count)
    end

    it 'returns payment source attributes' do
      get :index

      source_data = json_response['data'].first
      expect(source_data).to include('id', 'default')
    end

    it 'only returns payment sources belonging to the current user' do
      other_user = create(:user)
      other_card = create(:credit_card, user: other_user)
      other_source = create(:wallet_payment_source, user: other_user, payment_source: other_card)

      get :index

      ids = json_response['data'].map { |s| s['id'] }
      expect(ids).to include(payment_source.prefix_id)
      expect(ids).not_to include(other_source.prefix_id)
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the payment source' do
      get :show, params: { id: payment_source.prefix_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_source.prefix_id)
    end

    context 'when payment source belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_card) { create(:credit_card, user: other_user) }
      let(:other_source) { create(:wallet_payment_source, user: other_user, payment_source: other_card) }

      it 'returns not found' do
        get :show, params: { id: other_source.prefix_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: payment_source.prefix_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the payment source' do
      expect {
        delete :destroy, params: { id: payment_source.prefix_id }
      }.to change { user.wallet_payment_sources.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'when payment source belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_card) { create(:credit_card, user: other_user) }
      let(:other_source) { create(:wallet_payment_source, user: other_user, payment_source: other_card) }

      it 'returns not found' do
        expect {
          delete :destroy, params: { id: other_source.prefix_id }
        }.not_to change { Spree::WalletPaymentSource.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        delete :destroy, params: { id: payment_source.prefix_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
