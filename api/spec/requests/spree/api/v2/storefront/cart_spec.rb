require 'spec_helper'

describe 'API V2 Storefront Cart Spec', type: :request do
  let(:user)  { create(:user) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let(:order) { Spree::Order.last }

  shared_examples 'returns valid cart JSON' do
    it 'returns a valid cart JSON response' do
      expect(json_response['data']).to have_id(order.id.to_s)
      expect(json_response['data']).to have_type('cart')
      expect(json_response['data']).to have_attribute(:number).with_value(order.number)
      expect(json_response['data']).to have_attribute(:state).with_value('cart')
      expect(json_response['data']).to have_attribute(:token).with_value(order.token)
      expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
    end
  end

  shared_context 'creates order with line_item' do
    let!(:order)     { create(:order, user: user) }
    let!(:line_item) { create(:line_item, order: order) }
    let!(:headers)   { { 'Authorization' => "Bearer #{token.token}" } }
  end

  shared_context 'creates guest order with guest token' do
    let(:guest_token) { 'guest_token' }
    let!(:order)      { create(:order, token: guest_token) }
    let!(:line_item)  { create(:line_item, order: order) }
    let!(:headers)    { { 'X-Spree-Order-Token' => order.token } }
  end

  describe 'cart#create' do
    shared_examples 'creates an order' do
      it 'returns a proper HTTP status' do
        expect(response.status).to eq(201)
      end

      it_behaves_like 'returns valid cart JSON'
    end

    context 'for signed in user' do
      before do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart', headers: headers
      end

      it_behaves_like 'creates an order'

      it 'associates order with user' do
        expect(json_response['data']).to have_relationship(:user).with_data('id' => user.id.to_s, 'type' => 'user')
      end
    end

    context 'as guest user' do
      before do
        post '/api/v2/storefront/cart'
      end

      it_behaves_like 'creates an order'
    end
  end

  describe 'cart#add_item' do
    let(:variant) { create(:variant) }

    context 'without existing order' do
      it 'returns error' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers

        expect(response.status).to eq(404)
      end
    end

    context 'with existing order' do
      let!(:order) { create(:order, user: user) }

      it 'adds item to cart' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers

        expect(response.status).to eq(200)

        expect(order.line_items.count).to eq(1)
        expect(order.line_items.first.variant).to eq(variant)
        expect(order.line_items.first.quantity).to eq(5)

        expect(json_response['data']).to have_id(order.id.to_s)
        expect(json_response['data']).to have_type('cart')
        expect(json_response['data']).to have_attribute(:number).with_value(order.number)
        expect(json_response['data']).to have_attribute(:state).with_value('cart')
        expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
        expect(json_response['included']).to include(have_type('variant').and have_id(variant.id.to_s))
      end
    end

    context 'with existing guest order' do
      let(:custom_token) { 'custom_token' }
      let!(:order) { create(:order, token: custom_token) }

      it 'adds item to cart' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5, order_token: custom_token }, headers: headers

        expect(response.status).to eq(200)

        expect(order.line_items.count).to eq(1)
        expect(order.line_items.first.variant).to eq(variant)
        expect(order.line_items.first.quantity).to eq(5)

        expect(json_response['data']).to have_id(order.id.to_s)
        expect(json_response['data']).to have_type('cart')
        expect(json_response['data']).to have_attribute(:number).with_value(order.number)
        expect(json_response['data']).to have_attribute(:state).with_value('cart')
        expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
        expect(json_response['included']).to include(have_type('variant').and have_id(variant.id.to_s))
      end
    end
  end

  describe 'cart#remove_line_item' do
    shared_examples 'removes line item' do
      context 'without line items' do
        let!(:line_item) { create(:line_item) }

        it 'tries to remove an item and fails' do
          delete "/api/v2/storefront/cart/remove_line_item/#{line_item.id}", headers: headers

          expect(response.status).to eq(404)
        end
      end

      context 'containing line item' do
        let!(:line_item) { create(:line_item, order: order) }

        it 'removes line item from the cart' do
          delete "/api/v2/storefront/cart/remove_line_item/#{line_item.id}", headers: headers

          expect(response.status).to eq(200)
          expect(order.line_items.count).to eq(0)

          expect(json_response['data']).to have_id(order.id.to_s)
          expect(json_response['data']).to have_type('cart')
          expect(json_response['data']).to have_attribute(:number).with_value(order.number)
          expect(json_response['data']).to have_attribute(:state).with_value('cart')
          expect(json_response['data']).to have_relationships(:user, :line_items, :variants)
        end
      end
    end

    context 'without existing order' do
      let!(:line_item) { create(:line_item) }

      it 'returns error' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        delete "/api/v2/storefront/cart/remove_line_item/#{line_item.id}", headers: headers

        expect(response.status).to eq(404)
        expect(json_response[:error]).to eq('ActiveRecord::RecordNotFound')
      end
    end

    context 'existing order' do
      let!(:order) { create(:order, user: user) }
      let!(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

      it_behaves_like 'removes line item'
    end

    context 'as a guest' do
      let!(:order) { create(:order, user: user) }
      let!(:headers) { { 'X-Spree-Order-Token' => order.token } }

      it_behaves_like 'removes line item'
    end
  end

  describe 'cart#empty' do
    shared_examples 'emptying the order' do
      it 'empties the order' do
        post '/api/v2/storefront/cart/empty', headers: headers

        expect(response.status).to eq(200)
        expect(order.line_items.count).to eq(0)
      end
    end

    context 'without existing order' do
      it 'returns status code 404' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        post '/api/v2/storefront/cart/empty', headers: headers

        expect(response.status).to eq(404)
      end
    end

    context 'with existing order and line item' do
      include_context 'creates order with line_item'

      it_behaves_like 'emptying the order'
    end

    context 'with existing guest order and line item' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'emptying the order'
    end
  end

  describe 'cart#set_quantity' do
    let!(:order) { create(:order, user: user) }
    let!(:line_item) { create(:line_item, order: order) }

    context 'with insufficient stock quantity and non-backorderable item' do
      before do
        line_item.variant.stock_items.first.update(backorderable: false)
      end

      it 'returns 422 when there is not enough stock' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/cart/set_quantity', params: { order: order, line_item_id: line_item.id, quantity: 5, user: user }, headers: headers

        expect(response.status).to eq(422)
        expect(json_response[:error]).to eq('Insufficient stock quantity available')
      end
    end

    it 'changes the quantity of line_item' do
      headers = { 'Authorization' => "Bearer #{token.token}" }
      patch '/api/v2/storefront/cart/set_quantity', params: { order: order, line_item_id: line_item.id, quantity: 5, user: user }, headers: headers

      expect(response.status).to eq(200)
      expect(line_item.reload.quantity).to eq(5)
    end

    it 'returns 422 when quantity is 0' do
      headers = { 'Authorization' => "Bearer #{token.token}" }
      patch '/api/v2/storefront/cart/set_quantity', params: { order: order, line_item_id: line_item.id, quantity: 0, user: user }, headers: headers

      expect(response.status).to eq(422)
      expect(json_response[:error]).to eq('Quantity has to be greater than 0')
    end

    it 'returns 422 when quantity is absent' do
      headers = { 'Authorization' => "Bearer #{token.token}" }
      patch '/api/v2/storefront/cart/set_quantity', params: { order: order, line_item_id: line_item.id, user: user }, headers: headers

      expect(response.status).to eq(422)
      expect(json_response[:error]).to eq('Quantity has to be greater than 0')
    end
  end

  describe 'cart#show' do
    shared_examples 'showing the cart' do
      before do
        get '/api/v2/storefront/cart', headers: headers
      end

      it 'returns a proper HTTP status' do
        expect(response.status).to eq(200)
      end

      it_behaves_like 'returns valid cart JSON'
    end

    context 'without existing order' do
      let!(:headers) { { 'Authorization': "Bearer #{token.token}" } }

      it 'returns status 404' do
        get '/api/v2/storefront/cart', headers: headers

        expect(response.status).to eq(404)
      end
    end

    context 'with existing user order with line item' do
      include_context 'creates order with line_item'

      it_behaves_like 'showing the cart'
    end

    context 'with existing guest order' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'showing the cart'
    end
  end
end
