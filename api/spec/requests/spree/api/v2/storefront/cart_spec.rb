require 'spec_helper'

describe 'API V2 Storefront Cart Spec', type: :request do
  let(:default_currency) { 'USD' }
  let(:store) { create(:store, default_currency: default_currency) }
  let(:currency) { store.default_currency }
  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, store: store, currency: currency) }
  let(:variant) { create(:variant) }

  include_context 'API v2 tokens'

  shared_examples 'coupon code error' do
    it_behaves_like 'returns 422 HTTP status'

    it 'returns an error' do
      expect(json_response[:error]).to eq("The coupon code you entered doesn't exist. Please try again.")
    end
  end

  shared_context 'coupon codes' do
    let!(:line_item) { create(:line_item, order: order) }
    let!(:shipment) { create(:shipment, order: order) }
    let!(:promotion) { Spree::Promotion.create(name: 'Free shipping', code: 'freeship') }
    let(:coupon_code) { promotion.code }
    let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }
  end

  describe 'cart#create' do
    let(:order) { Spree::Order.last }
    let(:execute) { post '/api/v2/storefront/cart', headers: headers }

    shared_examples 'creates an order' do
      before { execute }

      it_behaves_like 'returns valid cart JSON'
      it_behaves_like 'returns 201 HTTP status'
    end

    shared_examples 'creates an order with different currency' do
      before do
        store.default_currency = 'EUR'
        store.save!
        execute
      end

      it_behaves_like 'returns valid cart JSON'
      it_behaves_like 'returns 201 HTTP status'

      it 'sets proper currency' do
        expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
      end
    end

    context 'as a signed in user' do
      let(:headers) { headers_bearer }

      it_behaves_like 'creates an order'
      it_behaves_like 'creates an order with different currency'

      context 'user association' do
        before { execute }

        it 'associates order with user' do
          expect(json_response['data']).to have_relationship(:user).with_data('id' => user.id.to_s, 'type' => 'user')
        end
      end
    end

    context 'as a guest user' do
      let(:headers) { {} }

      it_behaves_like 'creates an order'
      it_behaves_like 'creates an order with different currency'
    end
  end

  describe 'cart#add_item' do
    let(:options) { {} }
    let(:params) { { variant_id: variant.id, quantity: 5, options: options, include: 'variants' } }
    let(:execute) { post '/api/v2/storefront/cart/add_item', params: params, headers: headers }

    before do
      Spree::PermittedAttributes.line_item_attributes << :cost_price
    end

    shared_examples 'adds item' do
      before { execute }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns valid cart JSON'

      it 'with success' do
        expect(order.line_items.count).to eq(2)
        expect(order.line_items.last.variant).to eq(variant)
        expect(order.line_items.last.quantity).to eq(5)
        expect(json_response['included']).to include(have_type('variant').and(have_id(variant.id.to_s)))
      end

      context 'with options' do
        let(:options) { { cost_price: 1.99 } }

        it 'sets custom attributes values' do
          expect(order.line_items.last.cost_price).to eq(1.99)
        end
      end
    end

    shared_examples 'doesnt add item with quantity unnavailble' do
      before do
        variant.stock_items.first.update(backorderable: false)
        params[:quantity] = 11
        execute
      end

      it_behaves_like 'returns 422 HTTP status'

      it 'returns an error' do
        expect(json_response[:error]).to eq("Quantity selected of \"#{variant.name} (#{variant.options_text})\" is not available.")
      end
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      context 'with existing order' do
        it_behaves_like 'adds item'
        it_behaves_like 'doesnt add item with quantity unnavailble'
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      context 'with existing order' do
        it_behaves_like 'adds item'
        it_behaves_like 'doesnt add item with quantity unnavailble'
      end

      it_behaves_like 'no current order'
    end
  end

  describe 'cart#remove_line_item' do
    let(:execute) { delete "/api/v2/storefront/cart/remove_line_item/#{line_item.id}", headers: headers }

    shared_examples 'removes line item' do
      before { execute }

      context 'without line items' do
        let!(:line_item) { create(:line_item) }

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'containing line item' do
        let!(:line_item) { create(:line_item, order: order) }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'removes line item from the cart' do
          expect(order.line_items.count).to eq(0)
        end
      end
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      context 'with existing order' do
        it_behaves_like 'removes line item'
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      context 'with existing order' do
        it_behaves_like 'removes line item'
      end

      it_behaves_like 'no current order'
    end
  end

  describe 'cart#empty' do
    let(:execute) { patch '/api/v2/storefront/cart/empty', headers: headers }

    shared_examples 'emptying the order' do
      before { execute }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns valid cart JSON'

      it 'empties the order' do
        expect(order.reload.line_items.count).to eq(0)
      end
    end

    context 'as a signed in user' do
      context 'with existing order with line item' do
        include_context 'creates order with line item'

        it_behaves_like 'emptying the order'
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      context 'with existing guest order with line item' do
        include_context 'creates guest order with guest token'

        it_behaves_like 'emptying the order'
      end

      it_behaves_like 'no current order'
    end
  end

  describe 'cart#set_quantity' do
    let(:line_item) { create(:line_item, order: order) }
    let(:params) { { order: order, line_item_id: line_item.id, quantity: 5 } }
    let(:execute) { patch '/api/v2/storefront/cart/set_quantity', params: params, headers: headers }

    shared_examples 'wrong quantity parameter' do
      it_behaves_like 'returns 422 HTTP status'

      it 'returns an error' do
        expect(json_response[:error]).to eq('Quantity has to be greater than 0')
      end
    end

    shared_examples 'set quantity' do
      context 'non-existing line item' do
        before do
          params[:line_item_id] = 9999
          execute
        end

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'with insufficient stock quantity and non-backorderable item' do
        before do
          line_item.variant.stock_items.first.update(backorderable: false)
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response[:error]).to eq("Quantity selected of \"#{line_item.name}\" is not available.")
        end
      end

      context 'changes the quantity of line item' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'successfully changes the quantity' do
          expect(line_item.reload.quantity).to eq(5)
        end
      end

      context '0 passed as quantity' do
        before do
          params[:quantity] = 0
          execute
        end

        it_behaves_like 'wrong quantity parameter'
      end

      context 'quantity not passed' do
        before do
          params[:quantity] = nil
          execute
        end

        it_behaves_like 'wrong quantity parameter'
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'set quantity'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'set quantity'
    end
  end

  describe 'cart#show' do
    shared_examples 'showing the cart' do
      before do
        get '/api/v2/storefront/cart', headers: headers
      end

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns valid cart JSON'
    end

    shared_examples 'showing 404' do
      before do
        get '/api/v2/storefront/cart', headers: headers
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'without existing order' do
      let!(:headers) { headers_bearer }

      it_behaves_like 'showing 404'
    end

    context 'with existing user order with line item' do
      include_context 'creates order with line item'

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

    context 'with option: include' do
      let(:bill_addr_params) { { include: 'billing_address' } }
      let(:ship_addr_params) { { include: 'billing_address' } }

      include_context 'creates order with line item'
      it_behaves_like 'showing the cart'

      it 'will return included bill_address' do
        get '/api/v2/storefront/cart', params: bill_addr_params, headers: headers
        expect(json_response[:included][0]).to have_attribute(:firstname).with_value(order.bill_address.firstname)
        expect(json_response[:included][0]).to have_attribute(:lastname).with_value(order.bill_address.lastname)
        expect(json_response[:included][0]).to have_attribute(:address1).with_value(order.bill_address.address1)
        expect(json_response[:included][0]).to have_attribute(:address2).with_value(order.bill_address.address2)
        expect(json_response[:included][0]).to have_attribute(:city).with_value(order.bill_address.city)
        expect(json_response[:included][0]).to have_attribute(:zipcode).with_value(order.bill_address.zipcode)
        expect(json_response[:included][0]).to have_attribute(:phone).with_value(order.bill_address.phone)
        expect(json_response[:included][0]).to have_attribute(:state_name).with_value(order.bill_address.state_name_text)
        expect(json_response[:included][0]).to have_attribute(:company).with_value(order.bill_address.company)
        expect(json_response[:included][0]).to have_attribute(:country_name).with_value(order.bill_address.country_name)
        expect(json_response[:included][0]).to have_attribute(:country_iso3).with_value(order.bill_address.country_iso3)
        expect(json_response[:included][0]).to have_attribute(:state_code).with_value(order.bill_address.state_abbr)
      end

      it 'will return included ship_address' do
        get '/api/v2/storefront/cart', params: ship_addr_params, headers: headers

        expect(json_response[:included][0]).to have_attribute(:firstname).with_value(order.bill_address.firstname)
        expect(json_response[:included][0]).to have_attribute(:lastname).with_value(order.bill_address.lastname)
        expect(json_response[:included][0]).to have_attribute(:address1).with_value(order.bill_address.address1)
        expect(json_response[:included][0]).to have_attribute(:address2).with_value(order.bill_address.address2)
        expect(json_response[:included][0]).to have_attribute(:city).with_value(order.bill_address.city)
        expect(json_response[:included][0]).to have_attribute(:zipcode).with_value(order.bill_address.zipcode)
        expect(json_response[:included][0]).to have_attribute(:phone).with_value(order.bill_address.phone)
        expect(json_response[:included][0]).to have_attribute(:state_name).with_value(order.bill_address.state_name_text)
        expect(json_response[:included][0]).to have_attribute(:company).with_value(order.bill_address.company)
        expect(json_response[:included][0]).to have_attribute(:country_name).with_value(order.bill_address.country_name)
        expect(json_response[:included][0]).to have_attribute(:country_iso3).with_value(order.bill_address.country_iso3)
        expect(json_response[:included][0]).to have_attribute(:state_code).with_value(order.bill_address.state_abbr)
      end
    end
  end

  describe 'cart#apply_coupon_code' do
    include_context 'coupon codes'

    let(:params) { { coupon_code: coupon_code, include: 'promotions' } }
    let(:execute) { patch '/api/v2/storefront/cart/apply_coupon_code', params: params, headers: headers }

    shared_examples 'apply coupon code' do
      before { execute }

      context 'with coupon code for free shipping' do
        let(:adjustment_value) { -shipment.cost.to_f }
        let(:adjustment_value_in_money) { Spree::Money.new(adjustment_value, currency: order.currency) }

        context 'applies coupon code correctly' do
          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'changes the adjustment total' do
            expect(json_response['data']).to have_attribute(:promo_total).with_value(adjustment_value.to_s)
            expect(json_response['data']).to have_attribute(:display_promo_total).with_value(adjustment_value_in_money.to_s)
          end

          it 'includes the promotion in the response' do
            expect(json_response['included']).to include(have_type('promotion').and(have_id(promotion.id.to_s)))
            expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:amount).with_value(adjustment_value.to_s)))
            expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:display_amount).with_value(adjustment_value_in_money.to_s)))
            expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:code).with_value(promotion.code)))
          end
        end

        context 'does not apply the coupon code' do
          let!(:coupon_code) { 'zxr' }

          it_behaves_like 'coupon code error'
        end
      end

      context 'without coupon code' do
        context 'does not apply the coupon code' do
          let!(:coupon_code) { '' }

          it_behaves_like 'coupon code error'
        end
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      context 'with existing order' do
        it_behaves_like 'apply coupon code'
      end

      it_behaves_like 'no current order'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      context 'with existing order' do
        it_behaves_like 'apply coupon code'
      end

      it_behaves_like 'no current order'
    end
  end

  describe 'cart#remove_coupon_code' do
    let(:params) { { include: 'promotions' } }
    let(:execute) { delete "/api/v2/storefront/cart/remove_coupon_code/#{coupon_code}", params: params, headers: headers }

    include_context 'coupon codes'

    shared_examples 'remove coupon code' do
      context 'with coupon code applied' do
        before do
          order.coupon_code = promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
          order.save!
        end

        it 'has applied promotion' do
          expect(order.promotions).to include(promotion)
        end

        context 'removes coupon code correctly' do
          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'doesnt includes the promotion in the response' do
            expect(json_response['included']).not_to include(have_type('promotion'))
          end
        end

        context 'tries to remove not-applied promotion' do
          let(:coupon_code) { 'something-else' }

          before { execute }

          it_behaves_like 'coupon code error'
        end

        context 'tries to remove an empty string' do
          let!(:coupon_code) { '' }
  
          before { execute }
  
          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'doesnt includes the promotion in the response' do
            expect(json_response['included']).not_to include(have_type('promotion'))
          end
        end
  
        context 'tries to remove nil' do
          let(:coupon_code) { nil }
  
          before { execute }
  
          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'doesnt includes the promotion in the response' do
            expect(json_response['included']).not_to include(have_type('promotion'))
          end
        end
      end

      context 'when multiple coupon codes are applied' do
        let!(:promotion_with_item_adjustment) do
          create(
            :promotion_with_item_adjustment,
            code: 'line_item_promo'
          )
        end

        let!(:promotion_with_order_adjustment) do
          create(
            :promotion_with_order_adjustment,
            code: 'order_promo'
          )
        end

        before do
          order.coupon_code = promotion_with_item_adjustment.code
          Spree::PromotionHandler::Coupon.new(order).apply
          order.coupon_code = promotion_with_order_adjustment.code
          Spree::PromotionHandler::Coupon.new(order).apply
          order.save!
        end

        it 'has applied promotions' do
          expect(order.promotions).to include(promotion_with_item_adjustment, promotion_with_order_adjustment)
        end

        context 'removes coupon code correctly' do
          let!(:coupon_code) { promotion_with_order_adjustment.code }
          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).not_to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'includes the second promotion in the response' do
            expect(json_response['included']).to include(have_type('promotion'))
          end
        end

        context 'tries to remove an empty string' do
          let!(:coupon_code) { '' }
          before { execute }
  
          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'doesnt includes the promotion in the response' do
            expect(json_response['included']).not_to include(have_type('promotion'))
          end
        end
  
        context 'tries to remove nil' do
          let(:coupon_code) { nil }
          before { execute }
  
          it 'changes the adjustment total to 0.0' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
          end

          it 'doesnt includes the promotion in the response' do
            expect(json_response['included']).not_to include(have_type('promotion'))
          end
        end
      end

      context 'without coupon code applied' do
        context 'tries to remove not-applied promotion' do
          before { execute }

          it_behaves_like 'coupon code error'
        end
      end

      context 'without coupon code applied' do
        context 'tries to remove not-applied promotion' do
          before { execute }

          it_behaves_like 'coupon code error'
        end

        context 'tries to remove nil' do
          let(:coupon_code) { nil }
          before { execute }

          it_behaves_like 'returns 422 HTTP status'
        end

        context 'tries to remove an empty string' do
          let(:coupon_code) { '' }
          before { execute }

          it_behaves_like 'returns 422 HTTP status'
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'remove coupon code'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'remove coupon code'
    end
  end

  describe 'cart#estimate_shipping_rates' do
    let(:order) { create(:order, user: user, store: store, currency: currency) }
    let(:params) { { country_iso: 'USA' } }
    let(:execute) { get '/api/v2/storefront/cart/estimate_shipping_rates', params: params, headers: headers }

    let(:country) { create(:country, iso: 'USA') }
    let(:zone) { create(:zone, name: 'US') }
    let(:shipping_method) { create(:shipping_method) }
    let(:address) { create(:address, country: country) }

    let(:shipment) { order.shipments.first }
    let(:shipping_rate) { shipment.selected_shipping_rate }

    shared_examples 'returns a list of shipments with shipping rates' do
      before do
        order.shipping_address = address
        zone.countries << country
        shipping_method.zones = [zone]
        order.create_proposed_shipments
        execute
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns valid shipments JSON' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data'][0]).to have_type('shipping_rate')
        expect(json_response['data'][0]['attributes']).to be_present
        expect(json_response['data'][0]).to have_type('shipping_rate')
        expect(json_response['data'][0]).to have_attribute(:name).with_value(shipping_method.name)
        expect(json_response['data'][0]).to have_attribute(:cost).with_value(shipping_rate.cost.to_s)
        expect(json_response['data'][0]).to have_attribute(:tax_amount).with_value(shipping_rate.tax_amount.to_s)
        expect(json_response['data'][0]).to have_attribute(:shipping_method_id).with_value(shipping_method.id)
        expect(json_response['data'][0]).to have_attribute(:selected).with_value(shipping_rate.selected)
        expect(json_response['data'][0]).to have_attribute(:final_price).with_value(shipping_rate.final_price.to_s)
        expect(json_response['data'][0]).to have_attribute(:free).with_value(shipping_rate.free?)
        expect(json_response['data'][0]).to have_attribute(:display_final_price).with_value(shipping_rate.display_final_price.to_s)
        expect(json_response['data'][0]).to have_attribute(:display_cost).with_value(shipping_rate.display_cost.to_s)
        expect(json_response['data'][0]).to have_attribute(:display_tax_amount).with_value(shipping_rate.display_tax_amount.to_s)
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'returns a list of shipments with shipping rates'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'returns a list of shipments with shipping rates'
    end
  end
end
