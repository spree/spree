require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::WishlistsController, type: :request do
  let!(:store) { Spree::Store.default }
  let!(:other_store) { create(:store) }
  let!(:other_user) { create(:user) }

  let(:wishlist) { create(:wishlist) }
  let(:user) { wishlist.user }

  include_context 'API v2 tokens'

  describe '#default' do
    context 'no wishlist' do
      it 'must create default wishlist' do
        expect { get '/api/v2/storefront/wishlists/default', headers: headers_bearer }.to change { Spree::Wishlist.count }.from(0).to(2)
      end
    end

    context 'has default wishlist' do
      before do
        wishlist.update(is_default: true)
        wishlist.save
        wishlist.reload
      end

      after do
        wishlist.update(is_default: false)
        wishlist.save
        wishlist.reload
      end

      it 'must return the existing default wishlist' do
        expect { get '/api/v2/storefront/wishlists/default', headers: headers_bearer }.not_to change { Spree::Wishlist.count }
      end
    end

    context 'has default wishlist in other store' do
      before do
        wishlist.update(is_default: true, store: other_store)
        wishlist.save
        wishlist.reload
      end

      after do
        wishlist.update(is_default: false, store: store)
        wishlist.save
        wishlist.reload
      end

      it 'creates a new default wishlist for the current store' do
        expect { get '/api/v2/storefront/wishlists/default', headers: headers_bearer }.to change { Spree::Wishlist.count }.from(1).to(2)
      end
    end
  end

  describe '#index' do
    let!(:wishlists) { create_list(:wishlist, 30, user: user) }
    let!(:wishlist_for_other_user) { create_list(:wishlist, 5, user: other_user) }
    let!(:wishlists_other_store) { create_list(:wishlist, 5, user: user, store: other_store) }

    it 'must return a list of wishlists paged' do
      get '/api/v2/storefront/wishlists', headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].count).to eq (25)
    end

    it 'can request different pages' do
      get '/api/v2/storefront/wishlists?page=2', headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].count).to eq (6)
    end

    it 'can control paging size' do
      get '/api/v2/storefront/wishlists?page=2&per_page=10', headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].count).to eq (10)
    end
  end

  describe '#show' do
    let!(:wishlist_private) { create(:wishlist, user: other_user, is_private: true) }
    let!(:wishlist_public) { create(:wishlist, user: other_user, is_private: false) }

    let!(:wished_item) do
      wishlist.wished_items.create({ variant: create(:variant) })
    end

    it 'returns wishlist details' do
      get "/api/v2/storefront/wishlists/#{wishlist.token}?include=wished_items", headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['token']).to eq (wishlist.token)
      expect(json_response['data']['attributes']['name']).to eq (wishlist.name)
      expect(json_response['data']['attributes']['is_private']).to eq (wishlist.is_private?)
      expect(json_response['data']['attributes']['is_default']).to eq (wishlist.is_default?)
      expect(json_response['data']['relationships']['wished_items']['data'].first['id']).to eq(wished_item.id.to_s)
    end

    context 'when a request is sent by random user with no auth' do
      it 'returns 404 when wishlist is set to private' do
        get "/api/v2/storefront/wishlists/#{wishlist_private.token}"
        expect(response).to have_http_status(:not_found)
      end

      it 'returns wishlist when requested by public but is_private: false' do
        get "/api/v2/storefront/wishlists/#{wishlist_public.token}"

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['token']).to eq (wishlist_public.token)
        expect(json_response['data']['attributes']['name']).to eq (wishlist_public.name)
      end
    end
  end

  describe '#create' do
    it 'can create a new wishlist' do
      post '/api/v2/storefront/wishlists', headers: headers_bearer, params: {
        wishlist: {
          name: 'fathers day',
          is_private: '1',
          is_default: '1'
        }
      }
      expect(user.wishlists.count).to eq(2)
      expect(user.wishlists.last.name).to eq('fathers day')
    end

    it 'must require a name to create a wishlist' do
      post '/api/v2/storefront/wishlists', headers: headers_bearer, params: {
        wishlist: {
          bad_name: 'fathers day'
        }
      }
      expect(response.status).to eq(422)
      expect(json_response['error']).not_to be_empty
      expect(json_response['error']).to eq "Name can't be blank"
    end
  end

  describe '#update' do
    it 'must permit update wishlist name' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}", headers: headers_bearer, params: {
        wishlist: {
          name: 'books'
        }
      }
      expect(response.status).to eq(200)
      user.wishlists.reload
      expect(user.wishlists.first.name).to eq('books')
    end
  end

  describe '#destroy' do
    it 'must permite remove a wishlist' do
      delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}", headers: headers_bearer
      expect(response.status).to      eq (200)
      expect(user.wishlists.count).to eq (0)
    end
  end

  describe '#add_item' do
    let!(:variant) { create(:variant) }

    it 'must permit create wished_item' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    variant_id: variant.id.to_s,
                                                                                    quantity: 3
                                                                                  }
      expect(response.status).to eq(200)
      user.wishlists.reload

      expect(json_response['data']['type']).to eql ('wished_item')
      expect(json_response['data']['attributes']['quantity']).to eql (3)
      expect(json_response['data']['attributes']['price']).to eql ('19.99')
      expect(json_response['data']['attributes']['total']).to eql ('59.97')
      expect(json_response['data']['attributes']['display_price']).to eql ('$19.99')
      expect(json_response['data']['attributes']['display_total']).to eql ('$59.97')
      expect(json_response['data']['relationships']['variant']['data']['id']).to eql (variant.id.to_s)
      expect(json_response['data']['relationships']['variant']['data']['type']).to eql ('variant')
      expect(json_response['data']['relationships']['wishlist']['data']['id']).to eql (user.wishlists.first.id.to_s)
      expect(json_response['data']['relationships']['wishlist']['data']['type']).to eql ('wishlist')
    end

    context 'when variant is already in the wishlist' do
      let!(:set_variant) { create(:variant)}
      let!(:wi) { create(:wished_item, wishlist: user.wishlists.first, variant: set_variant, quantity: 1) }

      it 'quantity set must return the existing wished item' do
        post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                    params: {
                                                                                      variant_id: set_variant.id.to_s,
                                                                                      quantity: 1
                                                                                    }

        expect(response.status).to eq(200)
        user.wishlists.reload

        expect(json_response['data']['id']).to eql (wi.id.to_s)
        expect(json_response['data']['attributes']['quantity']).to eql (1)
      end

      it 'quantity omitted must return existing wished item with quantity 1' do
        post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                    params: {
                                                                                      variant_id: set_variant.id.to_s
                                                                                    }

        expect(response.status).to eq(200)
        user.wishlists.reload

        expect(json_response['data']['id']).to eql (wi.id.to_s)
        expect(json_response['data']['attributes']['quantity']).to eql (1)
      end
    end

    it 'must permit create wished_item when omitting the quantity attribute' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    variant_id: variant.id.to_s
                                                                                  }
      expect(response.status).to eq(200)
      user.wishlists.reload
      expect(json_response['data']['attributes']['quantity']).to eql (1)
    end

    it 'must not permit create new wished_item omitting the variant_id attribute' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    bad_variant_id: variant.id.to_s
                                                                                  }
      expect(response.status).to eq(422)
    end

    it 'must not permit create new wished_item with a quantity of 0' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    variant_id: variant.id.to_s,
                                                                                    quantity: 0
                                                                                  }
      expect(response.status).to eq(422)
    end
  end

  describe '#set_item_quantity' do
    let!(:wished_item) do
      wishlist.wished_items.create({ variant: create(:variant) })
    end

    it 'must permit update wishlist name' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: 17
            }

      expect(response.status).to eq(200)
      expect(json_response['data']['attributes']['quantity']).to eql (17)
    end
  end

  describe '#remove_item' do
    let!(:wished_item) do
      wishlist.wished_items.create({ variant: create(:variant) })
    end

    it 'must permit update wishlist name' do
      delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/remove_item/#{wishlist.wished_items.first.id}", headers: headers_bearer

      expect(response.status).to eq(200)
      expect(json_response['data']['type']).to eql ('wished_item')
    end

    context 'user not authorised to access this action' do
      it 'can not delete item from other users wishlist' do
        delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/remove_item/#{wishlist.wished_items.first.id}"

        expect(response.status).to eq(403)
      end
    end
  end
end
