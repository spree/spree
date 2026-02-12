require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::WishlistsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:wishlist) { create(:wishlist, user: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns user wishlists' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['id']).to eq(wishlist.prefixed_id)
    end

    it 'does not return other users wishlists' do
      other_user = create(:user)
      other_wishlist = create(:wishlist, user: other_user, store: store)

      get :index

      ids = json_response['data'].map { |w| w['id'] }
      expect(ids).not_to include(other_wishlist.prefixed_id)
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    it 'returns the wishlist' do
      get :show, params: { id: wishlist.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(wishlist.prefixed_id)
      expect(json_response['name']).to eq(wishlist.name)
    end

    context 'error handling' do
      it 'returns not found for non-existent wishlist' do
        get :show, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)

        get :show, params: { id: other_wishlist.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'POST #create' do
    it 'creates a new wishlist' do
      expect {
        post :create, params: { name: 'My New Wishlist' }
      }.to change(Spree::Wishlist, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('My New Wishlist')
    end

    it 'associates wishlist with current user' do
      post :create, params: { name: 'Test Wishlist' }

      expect(Spree::Wishlist.last.user_id).to eq(user.id)
    end

    it 'associates wishlist with current store' do
      post :create, params: { name: 'Test Wishlist' }

      expect(Spree::Wishlist.last.store_id).to eq(store.id)
    end

    context 'validation errors' do
      it 'returns errors for blank name' do
        post :create, params: { name: '' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['message']).to be_present
        expect(json_response['error']['details']['name']).to be_present
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: { name: 'Test' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the wishlist name' do
      patch :update, params: { id: wishlist.prefixed_id, name: 'Updated Name' }

      expect(response).to have_http_status(:ok)
      expect(wishlist.reload.name).to eq('Updated Name')
    end

    context 'validation errors' do
      it 'returns errors for blank name' do
        patch :update, params: { id: wishlist.prefixed_id, name: '' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['name']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)

        patch :update, params: { id: other_wishlist.prefixed_id, name: 'Hacked' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the wishlist' do
      expect {
        delete :destroy, params: { id: wishlist.prefixed_id }
      }.to change(Spree::Wishlist, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'error handling' do
      it 'returns not found for non-existent wishlist' do
        delete :destroy, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)

        delete :destroy, params: { id: other_wishlist.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
