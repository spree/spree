require 'spec_helper'

describe 'API V2 Storefront Cart Spec', type: :request do
  let!(:store) { create(:store) }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method, stores: [store]) }
  let(:currency) { store.default_currency }
  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, store: store, currency: currency) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product, prices: [create(:price, currency: store.default_currency)]) }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::CartController).to receive(:current_store).and_return(store)
  end

  include_context 'API v2 tokens'

  shared_examples 'coupon code error' do
    it 'returns an error' do
      expect(response.status).to eq(422)
      expect(json_response[:error]).to eq("The coupon code you entered doesn't exist. Please try again.")
    end
  end

  shared_context 'coupon codes' do
    let!(:line_item) { create(:line_item, order: order) }
    let!(:shipment) { create(:shipment, order: order) }
    let!(:promotion) { create(:promotion, name: 'Free shipping', code: 'freeship', stores: [store]) }
    let(:coupon_code) { promotion.code }
    let!(:promotion_action) { Spree::PromotionAction.create(promotion_id: promotion.id, type: 'Spree::Promotion::Actions::FreeShipping') }
  end

  describe 'cart#create' do
    let(:order) { Spree::Order.last }
    let(:params) { {} }
    let(:execute) { post '/api/v2/storefront/cart', headers: headers, params: params }

    shared_examples 'sets public and private metadata' do
      let(:params) do
        {
          public_metadata: { 'property1' => 'value1' },
          private_metadata: { 'property2' => 'value2' }
        }
      end

      it do
        expect(order.public_metadata).to eq(params[:public_metadata])
        expect(order.private_metadata).to eq(params[:private_metadata])
      end
    end

    shared_examples 'creates an order' do
      before { execute }

      it_behaves_like 'returns valid cart JSON'
      it_behaves_like 'returns 201 HTTP status'
      it_behaves_like 'sets public and private metadata'
    end

    shared_examples 'creates an order with different currency' do
      context 'store default' do
        before do
          store.default_currency = 'EUR'
          store.save!
          execute
        end

        it_behaves_like 'returns valid cart JSON'
        it_behaves_like 'returns 201 HTTP status'

        it 'sets requested currency' do
          expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
        end
      end

      context 'currency passed as a param' do
        let(:params) { { currency: 'EUR' } }

        before { execute }

        it_behaves_like 'returns valid cart JSON'
        it_behaves_like 'returns 201 HTTP status'

        it 'sets requested currency' do
          expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
        end
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

        context 'with canceled order' do
          let(:order) { create(:order, user: user, store: store, currency: currency, state: 'canceled') }

          before { execute }

          it_behaves_like 'returns 201 HTTP status'

          it 'returns a valid cart JSON response with new order' do
            new_order = Spree::Order.find(json_response['data']['id'])
            expect(json_response['data']).to be_present
            expect(json_response['data']).to have_id(new_order.id.to_s)
            expect(json_response['data']).to have_type('cart')
            expect(json_response['data']).to have_attribute(:number).with_value(new_order.number)
            expect(json_response['data']).to have_attribute(:state).with_value(new_order.state)
            expect(json_response['data']).to have_attribute(:payment_state).with_value(new_order.payment_state)
            expect(json_response['data']).to have_attribute(:shipment_state).with_value(new_order.shipment_state)
            expect(json_response['data']).to have_attribute(:token).with_value(new_order.token)
            expect(json_response['data']).to have_attribute(:total).with_value(new_order.total.to_s)
            expect(json_response['data']).to have_attribute(:total_minus_store_credits).with_value(new_order.total_minus_store_credits.to_s)
            expect(json_response['data']).to have_attribute(:display_total_minus_store_credits).with_value(new_order.display_total_minus_store_credits.to_s)
            expect(json_response['data']).to have_attribute(:item_total).with_value(new_order.item_total.to_s)
            expect(json_response['data']).to have_attribute(:ship_total).with_value(new_order.ship_total.to_s)
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(new_order.adjustment_total.to_s)
            expect(json_response['data']).to have_attribute(:included_tax_total).with_value(new_order.included_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:additional_tax_total).with_value(new_order.additional_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:display_additional_tax_total).with_value(new_order.display_additional_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:display_included_tax_total).with_value(new_order.display_included_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:tax_total).with_value(new_order.tax_total.to_s)
            expect(json_response['data']).to have_attribute(:currency).with_value(new_order.currency.to_s)
            expect(json_response['data']).to have_attribute(:email).with_value(new_order.email)
            expect(json_response['data']).to have_attribute(:display_item_total).with_value(new_order.display_item_total.to_s)
            expect(json_response['data']).to have_attribute(:display_ship_total).with_value(new_order.display_ship_total.to_s)
            expect(json_response['data']).to have_attribute(:display_adjustment_total).with_value(new_order.display_adjustment_total.to_s)
            expect(json_response['data']).to have_attribute(:display_tax_total).with_value(new_order.display_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:item_count).with_value(new_order.item_count)
            expect(json_response['data']).to have_attribute(:special_instructions).with_value(new_order.special_instructions)
            expect(json_response['data']).to have_attribute(:promo_total).with_value(new_order.promo_total.to_s)
            expect(json_response['data']).to have_attribute(:display_promo_total).with_value(new_order.display_promo_total.to_s)
            expect(json_response['data']).to have_attribute(:display_total).with_value(new_order.display_total.to_s)
            expect(json_response['data']).to have_attribute(:pre_tax_item_amount).with_value(new_order.pre_tax_item_amount.to_s)
            expect(json_response['data']).to have_attribute(:display_pre_tax_item_amount).with_value(new_order.display_pre_tax_item_amount.to_s)
            expect(json_response['data']).to have_attribute(:pre_tax_total).with_value(new_order.pre_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:display_pre_tax_total).with_value(new_order.display_pre_tax_total.to_s)
            expect(json_response['data']).to have_attribute(:public_metadata).with_value(new_order.public_metadata)
            expect(json_response['data']).to have_relationships(:user, :line_items, :variants, :billing_address, :shipping_address, :payments, :shipments, :promotions)
          end

          it 'does not return canceled order' do
            expect(json_response['data']).to have_attribute(:state).with_value('cart')
          end

          it 'creates the new order without line items' do
            expect(Spree::Order.find(json_response['data']['id']).line_items.count).to eq(0)
          end
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
    let(:params) do
      {
        variant_id: variant.id,
        quantity: 5,
        public_metadata: { 'prop1' => 'value1' },
        private_metadata: { 'prop2' => 'value2' },
        options: options,
        include: 'variants'
      }
    end
    let(:execute) { post '/api/v2/storefront/cart/add_item', params: params, headers: headers }

    before do
      Spree::PermittedAttributes.line_item_attributes << :cost_price
    end

    shared_examples 'adds item' do
      before { execute }

      it_behaves_like 'returns valid cart JSON'

      it 'with success' do
        order.reload

        expect(order.line_items.count).to eq(2)
        expect(order.line_items.last.variant).to eq(variant)
        expect(order.line_items.last.quantity).to eq(5)
        expect(order.line_items.last.public_metadata).to eq(params[:public_metadata])
        expect(order.line_items.last.private_metadata).to eq(params[:private_metadata])
        expect(json_response['included']).to include(have_type('variant').and(have_id(variant.id.to_s)))
      end

      context 'with options' do
        let(:options) { { cost_price: 1.99 } }

        it 'sets custom attributes values' do
          order.reload

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

      it 'returns an error' do
        expect(response.status).to eq(422)
        expect(json_response[:error]).to eq("Quantity selected of \"#{variant.name} (#{variant.options_text})\" is not available.")
      end
    end

    shared_examples 'doesnt add item from different store' do
      before do
        variant.product.stores = [create(:store)]
        execute
      end

      it 'returns an error' do
        expect(response.status).to eq(404)
        expect(json_response[:error]).to eq('The resource you were looking for could not be found.')
      end
    end

    shared_examples 'doesnt add non-existing item' do
      before do
        variant.destroy
        execute
      end

      it 'returns an error' do
        expect(response.status).to eq(404)
        expect(json_response[:error]).to eq('The resource you were looking for could not be found.')
      end
    end

    shared_examples 'doesnt add item if metadata is not a hash' do
      before do
        params[:public_metadata] = [1, 2, 3]
        execute
      end

      it 'return an error' do
        expect(response.status).to eq(422)
        expect(json_response[:error]).to eq(I18n.t(:invalid_params, scope: 'spree.api.v2.metadata'))
      end
    end

    shared_examples 'doesnt add item with no price with cart currency' do
      let(:variant) { create(:variant, product: product) }
      let(:price) { create(:price, currency: 'MKD') }

      before do
        variant.default_price = price
        variant.save
        execute
      end

      it 'returns an error' do
        expect(json_response[:error]).to eq("#{variant.name} is not available in #{order.currency}")
      end
    end

    context 'as a signed in user' do
      include_context 'order with a physical line item'

      context 'with existing order' do
        it_behaves_like 'adds item'
        it_behaves_like 'doesnt add item with quantity unnavailble'
        it_behaves_like 'doesnt add item from different store'
        it_behaves_like 'doesnt add non-existing item'
        it_behaves_like 'doesnt add item with no price with cart currency'
        it_behaves_like 'doesnt add item if metadata is not a hash'
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      context 'with existing order' do
        it_behaves_like 'adds item'
        it_behaves_like 'doesnt add item with quantity unnavailble'
        it_behaves_like 'doesnt add item from different store'
        it_behaves_like 'doesnt add non-existing item'
        it_behaves_like 'doesnt add item with no price with cart currency'
        it_behaves_like 'doesnt add item if metadata is not a hash'
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

        it_behaves_like 'returns valid cart JSON'

        it 'removes line item from the cart' do
          expect(order.line_items.count).to eq(0)
        end
      end
    end

    context 'as a signed in user' do
      include_context 'order with a physical line item'

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

      it_behaves_like 'returns valid cart JSON'

      it 'empties the order' do
        expect(order.reload.line_items.count).to eq(0)
      end
    end

    context 'as a signed in user' do
      context 'with existing order with line item' do
        include_context 'order with a physical line item'

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

  describe 'cart#destroy' do
    let(:execute) { delete '/api/v2/storefront/cart', headers: headers }

    shared_examples 'destroying order' do
      it 'destroys the order' do
        expect { execute }.to change { Spree::Order.count }.by(-1)
      end
    end

    shared_examples '204 status returned' do
      before { execute }

      it_behaves_like 'returns 204 HTTP status'
    end

    context 'as a signed in user' do
      context 'with existing order with line item' do
        include_context 'order with a physical line item'

        it_behaves_like 'destroying order'
        it_behaves_like '204 status returned'
        it_behaves_like 'no current order'
      end
    end

    context 'as a guest user' do
      context 'with existing guest order with line item' do
        include_context 'creates guest order with guest token'

        it_behaves_like 'destroying order'
        it_behaves_like '204 status returned'
        it_behaves_like 'no current order'
      end
    end
  end

  describe 'cart#set_quantity' do
    let(:line_item) { create(:line_item, order: order) }
    let(:params) { { order: order, line_item_id: line_item.id, quantity: 5 } }
    let(:execute) { patch '/api/v2/storefront/cart/set_quantity', params: params, headers: headers }

    shared_examples 'wrong quantity parameter' do
      it 'returns an error' do
        expect(response.status).to eq(422)
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

        it 'returns an error' do
          expect(response.status).to eq(422)
          expect(json_response[:error]).to eq("Quantity selected of \"#{line_item.name}\" is not available.")
        end
      end

      context 'changes the quantity of line item' do
        before { execute }

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
      include_context 'order with a physical line item'

      it_behaves_like 'set quantity'
    end
  end

  describe 'cart#show' do
    let(:params) { {} }

    shared_examples 'showing the cart' do
      before do
        get '/api/v2/storefront/cart', headers: headers, params: params
      end

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
      include_context 'order with a physical line item'

      it_behaves_like 'showing the cart'
    end

    context 'with existing guest order' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'showing the cart'
    end

    context 'for specified currency' do
      context 'store default' do
        include_context 'creates guest order with guest token'

        it_behaves_like 'showing the cart'

        it 'includes the same currency' do
          get '/api/v2/storefront/cart', headers: headers
          expect(json_response['data']).to have_attribute(:currency).with_value('USD')
        end
      end

      context 'passed as a param' do
        let(:currency) { 'EUR' }
        let(:params) { { currency: currency } }

        include_context 'creates guest order with guest token'

        it_behaves_like 'showing the cart'

        it 'includes the requested currency' do
          get '/api/v2/storefront/cart', headers: headers, params: params
          expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
        end
      end

      context 'as a signed user' do
        context 'with valid currency param' do
          include_context 'order with a physical line item'
          it_behaves_like 'showing the cart'

          it 'includes the requested currency' do
            get '/api/v2/storefront/cart', headers: headers, params: { currency: 'USD' }
            expect(json_response['data']).to have_attribute(:currency).with_value('USD')
          end
        end

        context 'with invalid currency param' do
          include_context 'order with a physical line item'
          it_behaves_like 'showing the cart'

          it 'includes the requested currency' do
            get '/api/v2/storefront/cart', headers: headers, params: { currency: 'PLN' }

            expect(json_response['data']['attributes']['currency']).to eq store.default_currency
          end
        end
      end
    end

    context 'with option: include' do
      let(:bill_addr_params) { { include: 'billing_address' } }
      let(:ship_addr_params) { { include: 'shipping_address' } }

      include_context 'order with a physical line item'
      it_behaves_like 'showing the cart'

      it 'returns included bill_address' do
        get '/api/v2/storefront/cart', params: bill_addr_params, headers: headers
        expect(json_response[:included][0]).to have_id(order.bill_address_id.to_s)
        expect(json_response[:included][0]).to have_type('address')
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
        expect(json_response[:included][0]).to have_attribute(:public_metadata).with_value(order.bill_address.public_metadata)
      end

      it 'returns included ship_address' do
        addr = create(:address)
        order.update(ship_address: addr)

        get '/api/v2/storefront/cart', params: ship_addr_params, headers: headers

        expect(json_response[:included][0]).to have_id(order.ship_address_id.to_s)
        expect(json_response[:included][0]).to have_type('address')
        expect(json_response[:included][0]).to have_attribute(:firstname).with_value(order.ship_address.firstname)
        expect(json_response[:included][0]).to have_attribute(:lastname).with_value(order.ship_address.lastname)
        expect(json_response[:included][0]).to have_attribute(:address1).with_value(order.ship_address.address1)
        expect(json_response[:included][0]).to have_attribute(:address2).with_value(order.ship_address.address2)
        expect(json_response[:included][0]).to have_attribute(:city).with_value(order.ship_address.city)
        expect(json_response[:included][0]).to have_attribute(:zipcode).with_value(order.ship_address.zipcode)
        expect(json_response[:included][0]).to have_attribute(:phone).with_value(order.ship_address.phone)
        expect(json_response[:included][0]).to have_attribute(:state_name).with_value(order.ship_address.state_name_text)
        expect(json_response[:included][0]).to have_attribute(:company).with_value(order.ship_address.company)
        expect(json_response[:included][0]).to have_attribute(:country_name).with_value(order.ship_address.country_name)
        expect(json_response[:included][0]).to have_attribute(:country_iso3).with_value(order.ship_address.country_iso3)
        expect(json_response[:included][0]).to have_attribute(:state_code).with_value(order.ship_address.state_abbr)
        expect(json_response[:included][0]).to have_attribute(:public_metadata).with_value(order.ship_address.public_metadata)
      end
    end

    context 'with gift card' do
      let(:gift_card) { create(:gift_card, amount: 10, store: store, amount_used: 10) }
      let(:order) { create(:order_with_line_items, store: store, user: nil, currency: store.default_currency, gift_card: gift_card) }

      before do
        get '/api/v2/storefront/cart', headers: headers_order_token, params: { include: 'gift_card' }
      end

      it 'should return an order with gift card' do
        expect(response.status).to eq(200)
        expect(json_response['included']).to include(have_type('gift_card').and(have_attribute(:code).with_value(gift_card.display_code)))
        expect(json_response['included']).to include(have_type('gift_card').and(have_attribute(:display_amount).with_value('$10.00')))
        expect(json_response['included']).to include(have_type('gift_card').and(have_attribute(:display_amount_remaining).with_value('$0.00')))
        expect(json_response['included']).to include(have_type('gift_card').and(have_attribute(:display_amount_used).with_value('$10.00')))
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

      context 'with coupon code for item discount' do
        let(:params) { { coupon_code: coupon_code, include: 'promotions,line_items' } }

        let!(:promotion) { create(:promotion, name: '10% off', code: '10off', stores: [store]) }
        let!(:promotion_action) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion_id: promotion.id, calculator: calculator) }
        let(:calculator) { Spree::Calculator::PercentOnLineItem.new(preferred_percent: 10) }

        let(:coupon_code) { promotion.code }

        it_behaves_like 'returns valid cart JSON'

        it 'changes the promo totals on order and line item' do
          expect(json_response['data']).to have_attribute(:item_total).with_value('10.0')
          expect(json_response['data']).to have_attribute(:ship_total).with_value('100.0')
          expect(json_response['data']).to have_attribute(:total).with_value('109.0')
          expect(json_response['data']).to have_attribute(:promo_total).with_value('-1.0')
          expect(json_response['data']).to have_attribute(:display_promo_total).with_value('-$1.00')

          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:price).with_value('10.0')))
          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:display_price).with_value('$10.00')))
          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:total).with_value('9.0')))
          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:display_total).with_value('$9.00')))
          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:promo_total).with_value('-1.0')))
          expect(json_response['included']).to include(have_type('line_item').and(have_attribute(:display_promo_total).with_value('-$1.00')))
        end

        it 'includes the promotion in the response' do
          expect(json_response['included']).to include(have_type('promotion').and(have_id(promotion.id.to_s)))
          expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:amount).with_value('-1.0')))
          expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:display_amount).with_value('-$1.00')))
          expect(json_response['included']).to include(have_type('promotion').and(have_attribute(:code).with_value(promotion.code)))
        end
      end

      context 'without coupon code' do
        context 'does not apply the coupon code' do
          let!(:coupon_code) { '' }

          it_behaves_like 'coupon code error'
        end
      end
    end

    shared_examples 'apply gift card coupon code' do
      before { execute }

      context 'apply gift card' do
        subject(:apply_gift_card) { patch '/api/v2/storefront/cart/apply_coupon_code', params: params, headers: headers }

        let(:execute) { nil }
        let(:gift_card) { create(:gift_card, amount: 10, store: store) }
        let(:coupon_code) { gift_card.code }
        let(:params) { { coupon_code: coupon_code, include: 'gift_card' } }

        it 'applies the gift card' do
          apply_gift_card
          expect(response.status).to eq(200)
          expect(json_response['included']).to include(have_type('gift_card').and(have_attribute(:code).with_value(gift_card.display_code)))
        end
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      context 'with existing order' do
        it_behaves_like 'apply coupon code'
        it_behaves_like 'apply gift card coupon code'
      end

      it_behaves_like 'no current order'
    end

    context 'as a signed in user' do
      include_context 'order with a physical line item'

      context 'with existing order' do
        it_behaves_like 'apply coupon code'
        it_behaves_like 'apply gift card coupon code'
      end

      it_behaves_like 'no current order'
    end
  end

  describe 'cart#remove_coupon_code' do
    let(:execute) { delete "/api/v2/storefront/cart/remove_coupon_code/#{coupon_code}?include=promotions", headers: headers }

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

        context 'removing the gift card' do
          let(:gift_card) { create(:gift_card, store: store) }
          let(:coupon_code) { gift_card.code }

          before do
            order.apply_gift_card(gift_card)
          end

          context 'when gift card is applied' do
            before { execute }

            it 'changes the adjustment total to 0.0' do
              expect(order.reload.gift_card_id).to be_nil
            end
          end
        end
      end

      xcontext 'when multiple coupon codes are applied' do
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

          it 'removes only the order promotion' do
            expect(json_response['included']).not_to include(have_type('promotion').and(have_id(promotion_with_order_adjustment.id.to_s)))
            expect(json_response['included']).to include(have_type('promotion').and(have_id(promotion_with_item_adjustment.id.to_s)))
          end
        end

        context 'tries to remove an empty string' do
          let!(:coupon_code) { '' }

          before { execute }

          it 'removes both promotions' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
            expect(json_response['included']).not_to include(have_type('promotion').and(have_id(promotion_with_order_adjustment.id.to_s)))
            expect(json_response['included']).not_to include(have_type('promotion').and(have_id(promotion_with_item_adjustment.id.to_s)))
          end
        end

        context 'tries to remove nil' do
          let(:coupon_code) { nil }

          before { execute }

          it 'removes both promotions' do
            expect(json_response['data']).to have_attribute(:adjustment_total).with_value(0.0.to_s)
            expect(json_response['included']).not_to include(have_type('promotion').and(have_id(promotion_with_order_adjustment.id.to_s)))
            expect(json_response['included']).not_to include(have_type('promotion').and(have_id(promotion_with_item_adjustment.id.to_s)))
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
      include_context 'order with a physical line item'

      it_behaves_like 'remove coupon code'
    end
  end

  describe 'cart#estimate_shipping_rates' do
    let(:order) { create(:order, user: user, store: store, currency: currency) }
    let(:params) { { country_iso: 'USA' } }
    let(:execute) { get '/api/v2/storefront/cart/estimate_shipping_rates', params: params, headers: headers }

    let(:country) { store.default_country || create(:country_us) }
    let(:state) { create(:state, country: country, name: 'New York', abbr: 'NY') }
    let(:zone) { create(:zone, name: 'US') }
    let(:shipping_method) { create(:shipping_method) }
    let(:shipping_method_2) { create(:shipping_method) }
    let(:address) { create(:address, country: country, state: state) }

    let(:shipment) { order.shipments.first }
    let(:shipping_rate) { shipment.selected_shipping_rate }
    let(:shipping_rate_2) { shipment.shipping_rates.where(selected: false).first }

    shared_examples 'returns a list of shipments with shipping rates' do
      before do
        order.shipping_address = address
        zone.countries << country
        shipping_method.zones = [zone]
        shipping_method_2.zones = [zone]
        order.create_proposed_shipments
        execute
      end

      it 'returns valid shipments JSON' do
        [{ shipping_method: shipping_method, shipping_rate: shipping_rate }, { shipping_method: shipping_method_2, shipping_rate: shipping_rate_2 }].each do |shipping|
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:name).with_value(shipping[:shipping_method].name)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:shipping_method_id).with_value(shipping[:shipping_method].id.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:cost).with_value(shipping[:shipping_rate].cost.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:tax_amount).with_value(shipping[:shipping_rate].tax_amount.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:selected).with_value(shipping[:shipping_rate].selected)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:final_price).with_value(shipping[:shipping_rate].final_price.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:free).with_value(shipping[:shipping_rate].free?)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:display_final_price).with_value(shipping[:shipping_rate].display_final_price.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:display_cost).with_value(shipping[:shipping_rate].display_cost.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_attribute(:display_tax_amount).with_value(shipping[:shipping_rate].display_tax_amount.to_s)))
          expect(json_response['data']).to include(have_type('shipping_rate').and(have_relationship(:shipping_method).with_data({ 'id' => shipping[:shipping_method].id.to_s, 'type' => 'shipping_method' })))
        end
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'returns a list of shipments with shipping rates'
    end

    context 'as a signed in user' do
      include_context 'order with a physical line item'

      it_behaves_like 'returns a list of shipments with shipping rates'
    end
  end

  describe 'cart#associate' do
    let(:order) { create(:order, user: assigned_user, store: store, currency: currency) }

    before do
      patch '/api/v2/storefront/cart/associate', params: { guest_order_token: guest_order_token }, headers: headers
    end

    context 'as a signed in user' do
      let(:headers) { headers_bearer }

      context 'when order was not assigned' do
        let(:assigned_user) { nil }
        let(:guest_order_token) { order.token }

        it_behaves_like 'returns valid cart JSON'
      end

      context 'when order was already assigned' do
        let(:assigned_user) { create(:user) }
        let(:guest_order_token) { order.token }

        it_behaves_like 'returns 422 HTTP status'
      end

      context 'when order token is invalid' do
        let(:assigned_user) { nil }
        let(:guest_order_token) { 'invalid' }

        it_behaves_like 'returns 403 HTTP status'
      end
    end

    context 'as a guest user' do
      let(:headers) {}
      let(:assigned_user) { nil }
      let(:guest_order_token) { order.token }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'cart#change_currency' do
    let(:order) { create(:order, store: store, currency: currency) }
    let!(:line_item) { create(:line_item, order: order) }
    let!(:price) { create(:price, currency: 'EUR', variant: order.line_items.first.variant) }

    before do
      patch '/api/v2/storefront/cart/change_currency', params: { currency: currency, new_currency: new_currency, order_token: order.token }, headers: headers
    end

    context 'when switching to supported currency' do
      let(:new_currency) { 'EUR' }

      it_behaves_like 'returns valid cart JSON'

      it 'sets cart currency to new currency' do
        expect(json_response['data']).to have_attribute(:currency).with_value('EUR')
      end
    end

    context 'when switching to unsupported currency' do
      let(:new_currency) { 'XOF' }

      it_behaves_like 'returns 422 HTTP status'
    end
  end
end
