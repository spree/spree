require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::WishlistsController, type: :request do
  let(:store) { create(:store) }
  let(:other_store) { create(:store) }

  let(:wishlist) { create(:wishlist, store: store) }
  let(:user) { wishlist.user }
  let(:other_user) { create(:user) }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::WishlistsController).to receive(:current_store).and_return(store)
  end

  include_context 'API v2 tokens'

  describe '#default' do
    context 'no wishlist' do
      it 'must create a new default wishlist' do
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

    context 'has default wishlist in another store' do
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
    let!(:wishlists) { create_list(:wishlist, 30, user: user, store: store) }

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
    let!(:wishlist_private) { create(:wishlist, user: other_user, is_private: true, store: store) }
    let!(:wishlist_public) { create(:wishlist, user: other_user, is_private: false, store: store) }

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
      expect(json_response['data']['attributes']['variant_included']).to be false
      expect(json_response['data']['relationships']['wished_items']['data'].first['id']).to eq(wished_item.id.to_s)
    end

    it 'returns is_variant_included true when the variant is already added to the wishlist' do
      get "/api/v2/storefront/wishlists/#{wishlist.token}?is_variant_included=#{wished_item.variant_id}", headers: headers_bearer

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['variant_included']).to be true
    end

    context 'when a request is sent by random user with no auth' do
      it 'returns 403 when wishlist is set to is_private: true' do
        get "/api/v2/storefront/wishlists/#{wishlist_private.token}"
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 200 when wishlist is set to is_private: false' do
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
    it 'must permit updating of the wishlist name' do
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
    it 'must permite destroying a wishlist' do
      delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}", headers: headers_bearer
      expect(response.status).to eq (204)
      expect(user.wishlists.count).to eq (0)
    end
  end

  describe '#add_item' do
    let!(:variant) { create(:variant) }

    it 'must allow creation of a wished_item' do
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
    end

    context 'when a variant is already in the wishlist' do
      let!(:set_variant) { create(:variant) }
      let!(:wi) { create(:wished_item, wishlist: user.wishlists.first, variant: set_variant, quantity: 1) }

      it 'return the existing wished_item - quantity attribute passed in' do
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

      it 'return the existing wished_item - quantity attribute ommited' do
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

    it 'must permit creation of a wished_item when omitting the quantity attribute' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    variant_id: variant.id.to_s
                                                                                  }
      expect(response.status).to eq(200)
      user.wishlists.reload
      expect(json_response['data']['attributes']['quantity']).to eql (1)
    end

    it 'must not permit the creation of a new wished_item without the variant_id attribute' do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_item", headers: headers_bearer,
                                                                                  params: {
                                                                                    bad_variant_id: variant.id.to_s
                                                                                  }
      expect(response.status).to eq(422)
    end

    it 'must not permit the creattion of a new wished_item with a quantity of 0' do
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

    it 'must allow setting the quantity when an integer value is passed in' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: 17
            }

      expect(response.status).to eq(200)
      expect(json_response['data']['attributes']['quantity']).to eql (17)
    end

    it 'must allow setting the quantity when an integer value is passed in' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: '18'
            }

      expect(response.status).to eq(200)
      expect(json_response['data']['attributes']['quantity']).to eql (18)
    end

    it 'must return error 422 if a random string is passed in as the quantity value' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: 'some string'
            }

      expect(response.status).to eq(422)
    end

    it 'must return error 422 if 0 is passed in as the quantity value' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: 0
            }

      expect(response.status).to eq(422)
    end

    it 'must return error 422 if "0" is passed in as the quantity value' do
      patch "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/set_item_quantity/#{wishlist.wished_items.first.id}",
            headers: headers_bearer,
            params: {
              quantity: '0'
            }

      expect(response.status).to eq(422)
    end
  end

  describe '#remove_item' do
    let!(:wished_item) do
      wishlist.wished_items.create({ variant: create(:variant) })
    end

    it 'must permit deletion of a wishlist' do
      delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/remove_item/#{wishlist.wished_items.first.id}", headers: headers_bearer

      expect(response.status).to eq(200)
      expect(json_response['data']['type']).to eql ('wished_item')
    end

    context 'user not authorised to access this action' do
      it 'can not delete an item from another users wishlist' do
        delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/remove_item/#{wishlist.wished_items.first.id}"

        expect(response.status).to eq(403)
      end
    end
  end

  describe '#add_items' do
    subject(:post_add_item) do
      post "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/add_items", headers: headers_bearer, params: params
    end

    let!(:variant) { create(:variant) }
    let!(:wished_item) { nil }
    let!(:wished_item_1) { nil }
    let!(:wished_item_2) { nil }
    let!(:wished_item_3) { nil }

    before { post_add_item }

    let(:params) do
      {
        wished_items: [
          { variant_id: variant.id.to_s, quantity: 3 }
        ]
      }
    end

    it 'returns wishlist in response' do
      expect(json_response['data']['type']).to eql ('wishlist')
      expect(json_response['data']['id']).to eql wishlist.id.to_s

      expect(json_response['data']['attributes']['token']).to eq wishlist.token
      expect(json_response['data']['attributes']['name']).to eq wishlist.name
      expect(json_response['data']['attributes']['is_private']).to be true
      expect(json_response['data']['attributes']['is_default']).to be false
      expect(json_response['data']['attributes']['variant_included']).to be false

      expect(json_response['data']['relationships']['wished_items']).not_to be_empty
    end

    it 'creates wished item' do
      expect(user.wishlists.reload.first.wished_items.take.quantity).to eq 3
    end

    context 'when many variants are passed' do
      let(:params) do
        {
          wished_items: [
            { variant_id: variant.id.to_s, quantity: 1 },
            { variant_id: variant_1.id.to_s, quantity: 2 },
            { variant_id: variant_2.id.to_s, quantity: 3 },
            { variant_id: variant_3.id.to_s, quantity: 4 }
          ]
        }
      end
      let(:variant_1) { create(:variant) }
      let(:variant_2) { create(:variant) }
      let(:variant_3) { create(:variant) }

      it 'creates many wished items' do
        expect(user.wishlists.reload.first.wished_items.count).to eq 4
      end

      context 'when some variants are already in the wishlist' do
        let!(:wished_item_1) { create(:wished_item, wishlist: user.wishlists.first, variant: variant_1, quantity: 1) }
        let!(:wished_item_2) { create(:wished_item, wishlist: user.wishlists.first, variant: variant_2, quantity: 1) }
        let!(:wished_item_3) { create(:wished_item, wishlist: user.wishlists.first, variant: variant_3, quantity: 1) }

        it 'updates them accordingly' do
          expect(wished_item_1.reload.quantity).to eq 2
          expect(wished_item_2.reload.quantity).to eq 3
          expect(wished_item_3.reload.quantity).to eq 4
        end
      end

      context 'when some of params is invalid' do
        let(:params) do
          {
            wished_items: [
              { variant_id: variant.id.to_s, quantity: 1 },
              { variant_id: create(:variant).id.to_s, quantity: 0 }
            ]
          }
        end

        it 'does not create any wished item' do
          expect(user.wishlists.reload.first.wished_items).to be_empty
        end
      end
    end

    context 'when a variant is already in the wishlist' do
      let!(:wished_item) { create(:wished_item, wishlist: user.wishlists.first, variant: wished_variant, quantity: 2) }
      let(:wished_variant) { create(:variant) }

      context 'when quantity is passed' do
        let(:params) do
          {
            wished_items: [
              { variant_id: wished_variant.id.to_s, quantity: 3 }
            ]
          }
        end

        it_behaves_like 'returns 200 HTTP status'

        it 'updates quantity' do
          expect(wished_item.reload.quantity).to eq 3
        end
      end

      context 'when quantity is not passed' do
        let(:params) do
          {
            wished_items: [
              { variant_id: wished_variant.id.to_s }
            ]
          }
        end

        it_behaves_like 'returns 200 HTTP status'

        it 'updates quantity to 1' do
          expect(wished_item.reload.quantity).to eq 1
        end
      end

      context 'when passed quantity is 0' do
        let(:params) do
          {
            wished_items: [
              { variant_id: wished_variant.id.to_s, quantity: 0 }
            ]
          }
        end

        it 'does not create wished item' do
          expect(user.wishlists.reload.first.wished_items.count).to eq 1
        end

        it 'returns error message' do
          expect(response.status).to eq(422)
          expect(json_response['error']).to eq 'Quantity must be greater than 0'
        end
      end
    end

    context 'when quantity is not passed' do
      let(:params) do
        {
          wished_items: [
            { variant_id: variant.id.to_s }
          ]
        }
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'creates wished item with quantity 1' do
        expect(user.wishlists.reload.first.wished_items.count).to eq 1
        expect(user.wishlists.first.wished_items.take.quantity).to eq 1
      end
    end

    context 'when variant_id is not passed' do
      let(:params) do
        {
          wished_items: [
            { quantity: 3 }
          ]
        }
      end

      it_behaves_like 'returns 422 HTTP status'

      it 'does not create wished item' do
        expect(user.wishlists.reload.first.wished_items).to be_empty
      end
    end

    context 'when passed quantity is 0' do
      let(:params) do
        {
          wished_items: [
            { variant_id: variant.id.to_s, quantity: 0 }
          ]
        }
      end

      it 'does not create wished item' do
        expect(user.wishlists.reload.first.wished_items).to be_empty
      end

      it 'returns error message' do
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq 'Quantity must be greater than 0'
      end
    end
  end

  describe '#remove_items' do
    subject(:remove_items) do
      delete "/api/v2/storefront/wishlists/#{user.wishlists.first.token}/remove_items", params: { wished_items_ids: wished_items_ids }, headers: headers_bearer
    end

    let!(:wished_item_1) { create(:wished_item, wishlist: user.wishlists.first, variant: create(:variant), quantity: 1) }
    let!(:wished_item_2) { create(:wished_item, wishlist: user.wishlists.first, variant: create(:variant), quantity: 2) }
    let!(:wished_item_3) { create(:wished_item, wishlist: user.wishlists.first, variant: create(:variant), quantity: 3) }
    let!(:wished_item_4) { create(:wished_item, wishlist: user.wishlists.first, variant: create(:variant), quantity: 4) }

    context 'when wished item is removed' do
      before { remove_items }

      let(:wished_items_ids) { [wished_item_2.id] }

      it 'returns wishlist in response' do
        expect(json_response['data']['type']).to eql ('wishlist')
        expect(json_response['data']['id']).to eql wishlist.id.to_s

        expect(json_response['data']['attributes']['token']).to eq wishlist.token
        expect(json_response['data']['attributes']['name']).to eq wishlist.name
        expect(json_response['data']['attributes']['is_private']).to be true
        expect(json_response['data']['attributes']['is_default']).to be false
        expect(json_response['data']['attributes']['variant_included']).to be false

        expect(json_response['data']['relationships']['wished_items']).not_to be_empty
      end

      context 'when there is one wished item to remove' do
        it_behaves_like 'returns 200 HTTP status'

        it 'removes wished item' do
          expect(wishlist.wished_items).to match_array([wished_item_1, wished_item_3, wished_item_4])
        end
      end

      context 'when there are many wished items to remove' do
        let(:wished_items_ids) { [wished_item_2.id, wished_item_3.id] }

        it_behaves_like 'returns 200 HTTP status'

        it 'removes wished items' do
          expect(wishlist.wished_items).to match_array([wished_item_1, wished_item_4])
        end
      end
    end

    context 'when wished item is not removed' do
      let(:wished_items_ids) { [wished_item_2.id] }

      before do
        allow_any_instance_of(ActiveRecord::RecordNotDestroyed).to receive_message_chain(:record, :errors, :full_messages, :to_sentence).and_return('some error')
        allow_any_instance_of(Spree::WishedItem).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
        remove_items
      end

      it_behaves_like 'returns 422 HTTP status'
    end

    context 'user not authorised to access this action' do
      let(:headers_bearer) { {} }
      let(:wished_items_ids) { [wished_item_2.id] }

      before { remove_items }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
