require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::WishlistItemsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:wishlist) { create(:wishlist, user: user, store: store) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist, variant: variant) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    let(:new_product) { create(:product, stores: [store]) }
    let(:new_variant) { create(:variant, product: new_product) }

    it 'adds item to wishlist' do
      expect {
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 3 }
      }.to change(Spree::WishedItem, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['variant_id']).to eq(new_variant.prefixed_id)
      expect(json_response['quantity']).to eq(3)
    end

    context 'validation errors' do
      it 'returns errors for missing variant_id' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns errors for invalid variant_id' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: 0, quantity: 1 }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['variant']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)

        post :create, params: { wishlist_id: other_wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for non-existent wishlist' do
        post :create, params: { wishlist_id: 0, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: { wishlist_id: wishlist.prefixed_id, variant_id: new_variant.prefixed_id, quantity: 1 }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates wished item quantity' do
      patch :update, params: { wishlist_id: wishlist.prefixed_id, id: wished_item.prefixed_id, quantity: 5 }

      expect(response).to have_http_status(:ok)
      expect(wished_item.reload.quantity).to eq(5)
    end

    context 'validation errors' do
      it 'returns errors for invalid quantity' do
        patch :update, params: { wishlist_id: wishlist.prefixed_id, id: wished_item.prefixed_id, quantity: 0 }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['quantity']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent item' do
        patch :update, params: { wishlist_id: wishlist.prefixed_id, id: 0, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for item in other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)
        other_item = create(:wished_item, wishlist: other_wishlist, variant: variant)

        patch :update, params: { wishlist_id: other_wishlist.prefixed_id, id: other_item.prefixed_id, quantity: 5 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'removes item from wishlist' do
      expect {
        delete :destroy, params: { wishlist_id: wishlist.prefixed_id, id: wished_item.prefixed_id }
      }.to change(Spree::WishedItem, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'error handling' do
      it 'returns not found for non-existent item' do
        delete :destroy, params: { wishlist_id: wishlist.prefixed_id, id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for item in other users wishlist' do
        other_user = create(:user)
        other_wishlist = create(:wishlist, user: other_user, store: store)
        other_item = create(:wished_item, wishlist: other_wishlist, variant: variant)

        delete :destroy, params: { wishlist_id: other_wishlist.prefixed_id, id: other_item.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
