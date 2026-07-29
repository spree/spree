require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::CreditCardsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:payment_method) { create(:credit_card_payment_method, store: store) }
  let!(:credit_card) { create(:credit_card, customer: user, payment_method: payment_method) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns the user credit cards' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(user.credit_cards.count)
    end

    it 'returns credit card attributes' do
      get :index

      card_data = json_response['data'].first
      expect(card_data).to include('id', 'last4', 'month', 'year', 'brand')
    end

    it 'only returns credit cards belonging to the current user' do
      other_user = create(:user)
      other_card = create(:credit_card, customer: other_user, payment_method: payment_method)

      get :index

      ids = json_response['data'].map { |c| c['id'] }
      expect(ids).to include(credit_card.prefixed_id)
      expect(ids).not_to include(other_card.prefixed_id)
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
    it 'returns the credit card' do
      get :show, params: { id: credit_card.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(credit_card.prefixed_id)
    end

    context 'when credit card belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_card) { create(:credit_card, customer: other_user, payment_method: payment_method) }

      it 'returns not found' do
        get :show, params: { id: other_card.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: credit_card.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the credit card' do
      expect {
        delete :destroy, params: { id: credit_card.prefixed_id }
      }.to change { user.credit_cards.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'when credit card belongs to another user' do
      let!(:other_user) { create(:user) }
      let!(:other_card) { create(:credit_card, customer: other_user, payment_method: payment_method) }

      it 'returns not found' do
        expect {
          delete :destroy, params: { id: other_card.prefixed_id }
        }.not_to change { Spree::CreditCard.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        delete :destroy, params: { id: credit_card.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'cross-store isolation' do
    let(:other_store) { create(:store) }
    let(:other_payment_method) { create(:credit_card_payment_method, store: other_store) }
    let!(:foreign_card) { create(:credit_card, customer: user, payment_method: other_payment_method) }

    it 'excludes cards from other stores in the index' do
      get :index

      ids = json_response['data'].map { |card| card['id'] }
      expect(ids).to include(credit_card.prefixed_id)
      expect(ids).not_to include(foreign_card.prefixed_id)
    end

    it 'cannot show a card stored against another store' do
      get :show, params: { id: foreign_card.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot delete a card stored against another store' do
      delete :destroy, params: { id: foreign_card.prefixed_id }

      expect(response).to have_http_status(:not_found)
      expect(Spree::CreditCard.exists?(foreign_card.id)).to be true
    end
  end
end
