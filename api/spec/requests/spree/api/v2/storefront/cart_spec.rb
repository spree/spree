require 'spec_helper'

describe 'API V2 Storefront Cart Spec', type: :request do
  let(:default_currency) { 'USD' }
  let(:store) { create(:store, default_currency: default_currency) }
  let(:currency) { store.default_currency }
  let(:user)  { create(:user) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let(:order) { Spree::Order.last }

  shared_examples 'returns valid cart JSON' do
    it 'returns a valid cart JSON response' do
      order.reload
      expect(json_response['data']).to have_id(order.id.to_s)
      expect(json_response['data']).to have_type('cart')
      expect(json_response['data']).to have_attribute(:number).with_value(order.number)
      expect(json_response['data']).to have_attribute(:state).with_value('cart')
      expect(json_response['data']).to have_attribute(:token).with_value(order.token)
      expect(json_response['data']).to have_attribute(:total).with_value(order.total.to_s)
      expect(json_response['data']).to have_attribute(:item_total).with_value(order.item_total.to_s)
      expect(json_response['data']).to have_attribute(:ship_total).with_value(order.ship_total.to_s)
      expect(json_response['data']).to have_attribute(:adjustment_total).with_value(order.adjustment_total.to_s)
      expect(json_response['data']).to have_attribute(:included_tax_total).with_value(order.included_tax_total.to_s)
      expect(json_response['data']).to have_attribute(:additional_tax_total).with_value(order.additional_tax_total.to_s)
      expect(json_response['data']).to have_attribute(:display_additional_tax_total).with_value(order.display_additional_tax_total.to_s)
      expect(json_response['data']).to have_attribute(:display_included_tax_total).with_value(order.display_included_tax_total.to_s)
      expect(json_response['data']).to have_attribute(:tax_total).with_value(order.tax_total.to_s)
      expect(json_response['data']).to have_attribute(:currency).with_value(order.currency.to_s)
      expect(json_response['data']).to have_attribute(:email).with_value(order.email)
      expect(json_response['data']).to have_attribute(:display_item_total).with_value(order.display_item_total.to_s)
      expect(json_response['data']).to have_attribute(:display_ship_total).with_value(order.display_ship_total.to_s)
      expect(json_response['data']).to have_attribute(:display_adjustment_total).with_value(order.display_adjustment_total.to_s)
      expect(json_response['data']).to have_attribute(:display_tax_total).with_value(order.display_tax_total.to_s)
      expect(json_response['data']).to have_attribute(:item_count).with_value(order.item_count)
      expect(json_response['data']).to have_attribute(:special_instructions).with_value(order.special_instructions)
      expect(json_response['data']).to have_attribute(:display_total).with_value(order.display_total.to_s)
      expect(json_response['data']).to have_relationships(:user, :line_items, :variants, :billing_address, :shipping_address, :payments, :shipments)
    end
  end

  shared_context 'creates order with line_item' do
    let!(:order)     { create(:order, user: user, store: store, currency: currency) }
    let!(:line_item) { create(:line_item, order: order, currency: currency) }
    let!(:headers)   { { 'Authorization' => "Bearer #{token.token}" } }
  end

  shared_context 'creates guest order with guest token' do
    let(:guest_token) { 'guest_token' }
    let!(:order)      { create(:order, token: guest_token, store: store, currency: currency) }
    let!(:line_item)  { create(:line_item, order: order, currency: currency) }
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

    context 'for specified currency' do
      before do
        store.update!(default_currency: 'EUR')
        post '/api/v2/storefront/cart'
      end

      it_behaves_like 'creates an order'

      it 'sets proper currency' do
        expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
      end
    end
  end

  describe 'cart#add_item' do
    let(:variant) { create(:variant) }
    let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

    shared_examples 'adds item' do
      it 'with success' do
        expect(response.status).to eq(200)
        expect(order.line_items.count).to eq(1)
        expect(order.line_items.first.variant).to eq(variant)
        expect(order.line_items.first.quantity).to eq(5)
        expect(json_response['included']).to include(have_type('variant').and have_id(variant.id.to_s))
      end
    end

    context 'without existing order' do
      it 'returns error' do
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers

        expect(response.status).to eq(404)
      end
    end

    context 'with existing order' do
      let!(:order) { create(:order, user: user, store: store, currency: currency) }

      before do
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5 }, headers: headers
      end

      it_behaves_like 'adds item'

      it_behaves_like 'returns valid cart JSON'
    end

    context 'with existing guest order' do
      let(:custom_token) { 'custom_token' }
      let!(:order) { create(:order, token: custom_token, store: store, currency: currency) }

      before do
        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5, order_token: custom_token }, headers: headers
      end

      it_behaves_like 'adds item'

      it_behaves_like 'returns valid cart JSON'
    end

    context 'with options' do
      let!(:order) { create(:order, user: user, store: store, currency: currency) }
      let(:options) { { cost_price: 1.99 } }

      before do
        Spree::PermittedAttributes.line_item_attributes << :cost_price

        post '/api/v2/storefront/cart/add_item', params: { variant_id: variant.id, quantity: 5, options: options }, headers: headers
      end

      it_behaves_like 'adds item'

      it_behaves_like 'returns valid cart JSON'

      it 'sets custom attributes values' do
        expect(order.line_items.first.cost_price).to eq(1.99)
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
      let!(:order) { create(:order, user: user, store: store, currency: currency) }
      let!(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

      it_behaves_like 'removes line item'
    end

    context 'as a guest' do
      let!(:order) { create(:order, user: user, store: store, currency: currency) }
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
    let!(:order) { create(:order, user: user, store: store, currency: currency) }
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

    shared_examples 'showing 404' do
      it 'returns status 404' do
        get '/api/v2/storefront/cart', headers: headers

        expect(response.status).to eq(404)
      end
    end

    context 'without existing order' do
      let!(:headers) { { 'Authorization': "Bearer #{token.token}" } }

      it_behaves_like 'showing 404'
    end

    context 'with existing user order with line item' do
      include_context 'creates order with line_item'

      it_behaves_like 'showing the cart'
    end

    context 'with existing guest order' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'showing the cart'
    end

    context 'for specified currency' do
      before do
        store.update!(default_currency: 'EUR')
      end

      context 'with matching currency' do
        include_context 'creates guest order with guest token'

        it_behaves_like 'showing the cart'

        it 'includes the same currency' do
          get '/api/v2/storefront/cart', headers: headers
          expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
        end
      end
    end
  end

  describe 'cart#add_coupon' do
    let!(:order) { create(:order, user: user, store: store, currency: currency) }
    let!(:line_item) { create(:line_item, order: order) }
    let!(:shipment) { create(:shipment, order: order) }
    let!(:promotion) { Spree::Promotion.create(name: 'Free shipping', code: 'freeship') }
    let(:coupon_code) { promotion.code }
    let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }

    context 'with coupon code for free shipping' do
      let(:adjustment_value) { -(shipment.cost.to_f) }

      it 'applies coupon code correctly' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/cart/apply_coupon_code', params: { user: user, coupon_code: coupon_code }, headers: headers

        expect(json_response['data']).to have_attribute(:adjustment_total).with_value(adjustment_value.to_s)
      end

      it 'does not apply the coupon code' do
        headers = { 'Authorization' => "Bearer #{token.token}" }
        patch '/api/v2/storefront/cart/apply_coupon_code', params: { user: user, coupon_code: 'zxr' }, headers: headers

        expect(response.status).to eq(422)
      end
    end

  end
end
