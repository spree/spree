require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::WishlistsController, type: :request do
  let!(:store) { Spree::Store.default }
  let!(:other_store) { create(:store) }
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

      it 'must return wishlist' do
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

      it 'creates a default wishlist for the current store' do
        expect { get '/api/v2/storefront/wishlists/default', headers: headers_bearer }.to change { Spree::Wishlist.count }.from(1).to(2)
      end
    end
  end

  describe '#index' do
    let!(:wishlists) { create_list(:wishlist, 30, user: user) }
    let!(:wishlists_other_store) { create_list(:wishlist, 5, user: user, store: other_store ) }

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
    let!(:wished_variant) do
      wishlist.wished_variants.create({ variant: create(:variant) })
    end

    it 'returns wish list details' do
      get "/api/v2/storefront/wishlists/#{wishlist.token}?include=wished_variants", headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['token']).to eq (wishlist.token)
      expect(json_response['data']['attributes']['name']).to eq (wishlist.name)
      expect(json_response['data']['attributes']['is_private']).to eq (wishlist.is_private?)
      expect(json_response['data']['attributes']['is_default']).to eq (wishlist.is_default?)
      expect(json_response['data']['relationships']['wished_variants']['data'].first['id']).to eq(wished_variant.id.to_s)
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
end
