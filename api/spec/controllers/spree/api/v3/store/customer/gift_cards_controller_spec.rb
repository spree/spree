require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::GiftCardsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:gift_card) { create(:gift_card, user: user, store: store, amount: 100, amount_used: 25) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns the user gift cards' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(user.gift_cards.where(store: store).count)
    end

    it 'returns gift card attributes' do
      get :index

      card_data = json_response['data'].first
      expect(card_data).to include(
        'id',
        'code',
        'state',
        'amount',
        'amount_used',
        'amount_remaining',
        'display_amount',
        'display_amount_used',
        'display_amount_remaining',
        'currency',
        'expires_at',
        'expired',
        'active'
      )
    end

    it 'returns correct amounts' do
      get :index

      card_data = json_response['data'].first
      expect(card_data['amount']).to eq(100.0)
      expect(card_data['amount_used']).to eq(25.0)
      expect(card_data['amount_remaining']).to eq(75.0)
    end

    it 'only returns gift cards belonging to the current user' do
      other_user = create(:user)
      other_card = create(:gift_card, user: other_user, store: store)

      get :index

      ids = json_response['data'].map { |c| c['id'] }
      expect(ids).to include(gift_card.prefix_id)
      expect(ids).not_to include(other_card.prefix_id)
    end

    it 'only returns gift cards from the current store' do
      other_store = create(:store)
      other_store_card = create(:gift_card, user: user, store: other_store)

      get :index

      ids = json_response['data'].map { |c| c['id'] }
      expect(ids).to include(gift_card.prefix_id)
      expect(ids).not_to include(other_store_card.prefix_id)
    end

    it 'returns gift cards ordered by created_at desc' do
      older_card = create(:gift_card, user: user, store: store, created_at: 1.day.ago)
      newer_card = create(:gift_card, user: user, store: store, created_at: 1.day.from_now)

      get :index

      ids = json_response['data'].map { |c| c['id'] }
      expect(ids.first).to eq(newer_card.prefix_id)
      expect(ids.last).to eq(older_card.prefix_id)
    end

    context 'with expired gift card' do
      let!(:expired_card) { create(:gift_card, user: user, store: store, expires_at: 1.day.ago) }

      it 'includes expired gift cards' do
        get :index

        ids = json_response['data'].map { |c| c['id'] }
        expect(ids).to include(expired_card.prefix_id)
      end

      it 'shows correct expired state' do
        get :index

        expired_data = json_response['data'].find { |c| c['id'] == expired_card.prefix_id }
        expect(expired_data['expired']).to be true
        expect(expired_data['active']).to be false
        expect(expired_data['state']).to eq('expired')
      end
    end

    context 'with partially redeemed gift card' do
      let!(:partial_card) { create(:gift_card, user: user, store: store, state: :partially_redeemed, amount: 50, amount_used: 20) }

      it 'shows correct state and amounts' do
        get :index

        partial_data = json_response['data'].find { |c| c['id'] == partial_card.prefix_id }
        expect(partial_data['state']).to eq('partially_redeemed')
        expect(partial_data['amount_remaining']).to eq(30.0)
      end
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
    it 'returns the gift card' do
      get :show, params: { id: gift_card.prefix_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(gift_card.prefix_id)
    end

    it 'returns gift card with all attributes' do
      get :show, params: { id: gift_card.prefix_id }

      expect(json_response['code']).to eq(gift_card.display_code)
      expect(json_response['amount']).to eq(100.0)
      expect(json_response['amount_used']).to eq(25.0)
      expect(json_response['amount_remaining']).to eq(75.0)
      expect(json_response['currency']).to eq(gift_card.currency)
    end

    context 'when gift card belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_card) { create(:gift_card, user: other_user, store: store) }

      it 'returns not found' do
        get :show, params: { id: other_card.prefix_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when gift card belongs to another store' do
      let(:other_store) { create(:store) }
      let(:other_store_card) { create(:gift_card, user: user, store: other_store) }

      it 'returns not found' do
        get :show, params: { id: other_store_card.prefix_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: gift_card.prefix_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
