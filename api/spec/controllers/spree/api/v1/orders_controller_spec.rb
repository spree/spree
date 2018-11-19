require 'spec_helper'
require 'spree/testing_support/bar_ability'

module Spree
  describe Api::V1::OrdersController, type: :controller do
    render_views

    let!(:order)    { create(:order) }
    let(:variant)   { create(:variant) }
    let(:line_item) { create(:line_item) }

    let(:attributes) do
      [:number, :item_total, :display_total, :total, :state, :adjustment_total, :user_id,
       :created_at, :updated_at, :completed_at, :payment_total, :shipment_state, :payment_state,
       :email, :special_instructions, :total_quantity, :display_item_total, :currency, :considered_risky]
    end

    let(:address_params) { { country_id: Country.first.id, state_id: State.first.id } }

    let(:current_api_user) do
      user = Spree.user_class.new(email: 'spree@example.com')
      user.generate_spree_api_key!
      user
    end

    before do
      stub_authentication!
    end

    it 'cannot view all orders' do
      api_get :index
      assert_unauthorized!
    end

    context 'the current api user is not persisted' do
      let(:current_api_user) { Spree.user_class.new }

      it 'returns a 401' do
        api_get :mine
        expect(response.status).to eq(401)
      end
    end

    context 'the current api user is authenticated' do
      let(:current_api_user) { order.user }
      let(:order)            { create(:order, line_items: [line_item]) }

      it 'can view all of their own orders' do
        api_get :mine

        expect(response.status).to eq(200)
        expect(json_response['pages']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['orders'].length).to eq(1)
        expect(json_response['orders'].first['number']).to eq(order.number)
        expect(json_response['orders'].first['line_items'].length).to eq(1)
        expect(json_response['orders'].first['line_items'].first['id']).to eq(line_item.id)
      end

      it 'can filter the returned results' do
        api_get :mine, q: { completed_at_not_null: 1 }

        expect(response.status).to eq(200)
        expect(json_response['orders'].length).to eq(0)
      end

      it 'returns orders in reverse chronological order by completed_at' do
        Timecop.scale(3600) do
          order.update_columns completed_at: Time.current

          order2 = Order.create user: order.user, completed_at: Time.current - 1.day
          expect(order2.created_at).to be > order.created_at
          order3 = Order.create user: order.user, completed_at: nil
          expect(order3.created_at).to be > order2.created_at
          order4 = Order.create user: order.user, completed_at: nil
          expect(order4.created_at).to be > order3.created_at

          api_get :mine
          expect(response.status).to eq(200)
          expect(json_response['pages']).to eq(1)
          expect(json_response['orders'].length).to eq(4)
          expect(json_response['orders'][0]['number']).to eq(order.number)
          expect(json_response['orders'][1]['number']).to eq(order2.number)
          expect(json_response['orders'][2]['number']).to eq(order4.number)
          expect(json_response['orders'][3]['number']).to eq(order3.number)
        end
      end
    end

    describe 'current' do
      subject do
        api_get :current, format: 'json'
      end

      let(:current_api_user) { order.user }
      let!(:order) { create(:order, line_items: [line_item]) }

      context 'an incomplete order exists' do
        it 'returns that order' do
          expect(JSON.parse(subject.body)['id']).to eq order.id
          expect(subject).to be_successful
        end
      end

      context 'multiple incomplete orders exist' do
        it 'returns the latest incomplete order' do
          Timecop.scale(3600) do
            new_order = Spree::Order.create! user: order.user
            expect(new_order.created_at).to be > order.created_at
            expect(JSON.parse(subject.body)['id']).to eq new_order.id
          end
        end
      end

      context 'an incomplete order does not exist' do
        before do
          order.update_attribute(:state, order_state)
          order.update_attribute(:completed_at, 5.minutes.ago)
        end

        ['complete', 'returned', 'awaiting_return'].each do |order_state|
          context "order is in the #{order_state} state" do
            let(:order_state) { order_state }

            it 'returns no content' do
              expect(subject.status).to eq 204
              expect(subject.body).to be_blank
            end
          end
        end
      end
    end

    it 'can view their own order' do
      allow_any_instance_of(Order).to receive_messages user: current_api_user
      api_get :show, id: order.to_param
      expect(response.status).to eq(200)
      expect(json_response).to have_attributes(attributes)
      expect(json_response['adjustments']).to be_empty
    end

    describe 'GET #show' do
      subject { api_get :show, id: order.to_param }

      let(:order)      { create :order_with_line_items }
      let(:adjustment) { FactoryBot.create(:adjustment, order: order) }

      before do
        allow_any_instance_of(Order).to receive_messages user: current_api_user
      end

      context 'when inventory information is present' do
        it 'contains stock information on variant' do
          subject
          variant = json_response['line_items'][0]['variant']
          expect(variant).not_to be_nil
          expect(variant['in_stock']).to eq(false)
          expect(variant['total_on_hand']).to eq(0)
          expect(variant['is_backorderable']).to eq(true)
          expect(variant['is_destroyed']).to eq(false)
        end
      end

      context 'when shipment adjustments are present' do
        before do
          order.shipments.first.adjustments << adjustment
        end

        it 'contains adjustments on shipment' do
          subject

          # Test to insure shipment has adjustments
          shipment = json_response['shipments'][0]
          expect(shipment).not_to be_nil
          expect(shipment['adjustments'][0]).not_to be_empty
          expect(shipment['adjustments'][0]['label']).to eq(adjustment.label)
        end
      end
    end

    it 'order contains the basic checkout steps' do
      allow_any_instance_of(Order).to receive_messages user: current_api_user
      api_get :show, id: order.to_param
      expect(response.status).to eq(200)
      expect(json_response['checkout_steps']).to eq(['address', 'delivery', 'complete'])
    end

    # Regression test for #1992
    it 'can view an order not in a standard state' do
      allow_any_instance_of(Order).to receive_messages user: current_api_user
      order.update_column(:state, 'shipped')
      api_get :show, id: order.to_param
    end

    it "can not view someone else's order" do
      allow_any_instance_of(Order).to receive_messages user: stub_model(Spree::LegacyUser)
      api_get :show, id: order.to_param
      assert_unauthorized!
    end

    it 'can view an order if the token is known' do
      api_get :show, id: order.to_param, order_token: order.token
      expect(response.status).to eq(200)
    end

    it 'can view an order if the token is passed in header' do
      request.headers['X-Spree-Order-Token'] = order.token
      api_get :show, id: order.to_param
      expect(response.status).to eq(200)
    end

    context 'with BarAbility registered' do
      before { Spree::Ability.register_ability(::BarAbility) }

      after  { Spree::Ability.remove_ability(::BarAbility) }

      it 'can view an order' do
        user = mock_model(Spree::LegacyUser)
        allow(user).to receive_message_chain(:spree_roles, :pluck).and_return(['bar'])
        allow(user).to receive(:has_spree_role?).with('bar').and_return(true)
        allow(user).to receive(:has_spree_role?).with('admin').and_return(false)
        allow(Spree.user_class).to receive_messages find_by: user
        api_get :show, id: order.to_param
        expect(response.status).to eq(200)
      end
    end

    it "cannot cancel an order that doesn't belong to them" do
      order.update_attribute(:completed_at, Time.current)
      order.update_attribute(:shipment_state, 'ready')
      api_put :cancel, id: order.to_param
      assert_unauthorized!
    end

    it 'can create an order' do
      api_post :create, order: { line_items: { '0' => { variant_id: variant.to_param, quantity: 5 } } }
      expect(response.status).to eq(201)

      order = Order.last
      expect(order.line_items.count).to eq(1)
      expect(order.line_items.first.variant).to eq(variant)
      expect(order.line_items.first.quantity).to eq(5)

      expect(json_response['number']).to be_present
      expect(json_response['token']).not_to be_blank
      expect(json_response['state']).to eq('cart')
      expect(order.user).to eq(current_api_user)
      expect(order.email).to eq(current_api_user.email)
      expect(json_response['user_id']).to eq(current_api_user.id)
    end

    it 'assigns email when creating a new order' do
      api_post :create, order: { email: 'guest@spreecommerce.org' }
      expect(json_response['email']).not_to eq controller.current_api_user
      expect(json_response['email']).to eq 'guest@spreecommerce.org'
    end

    it 'cannot arbitrarily set the line items price' do
      api_post :create, order: {
        line_items: { '0' => { price: 33.0, variant_id: variant.to_param, quantity: 5 } }
      }

      expect(response.status).to eq 201
      expect(Order.last.line_items.first.price.to_f).to eq(variant.price)
    end

    context 'admin user imports order' do
      before do
        allow(current_api_user).to receive_messages has_spree_role?: true
        allow(current_api_user).to receive_message_chain :spree_roles, pluck: ['admin']
      end

      it 'is able to set any default unpermitted attribute' do
        api_post :create, order: { number: 'WOW' }
        expect(response.status).to eq 201
        expect(json_response['number']).to eq 'WOW'
      end
    end

    it 'can create an order without any parameters' do
      expect { api_post :create }.not_to raise_error
      expect(response.status).to eq(201)
      expect(json_response['state']).to eq('cart')
    end

    context 'working with an order' do
      let(:variant)        { create(:variant) }
      let!(:line_item)     { Spree::Cart::AddItem.call(order: order, variant: variant).value }
      let(:address_params) { { country_id: country.id } }
      let(:billing_address) do
        {
          firstname: 'Tiago', lastname: 'Motta', address1: 'Av Paulista',
          city: 'Sao Paulo', zipcode: '01310-300', phone: '12345678',
          country_id: country.id
        }
      end
      let(:shipping_address) do
        {
          firstname: 'Tiago', lastname: 'Motta', address1: 'Av Paulista',
          city: 'Sao Paulo', zipcode: '01310-300', phone: '12345678',
          country_id: country.id
        }
      end
      let(:country) { create(:country, name: 'Brazil', iso_name: 'BRAZIL', iso: 'BR', iso3: 'BRA', numcode: 76) }

      before do
        allow_any_instance_of(Order).to receive_messages user: current_api_user
        order.next # Switch from cart to address
        order.bill_address = nil
        order.ship_address = nil
        order.save
        expect(order.state).to eq('address')
      end

      def clean_address(address)
        address.delete(:state)
        address.delete(:country)
        address
      end

      context 'line_items hash not present in request' do
        it 'responds successfully' do
          api_put :update, id: order.to_param, order: {
            email: 'hublock@spreecommerce.com'
          }

          expect(response).to be_successful
        end
      end

      it 'updates quantities of existing line items' do
        api_put :update, id: order.to_param, order: {
          line_items: {
            '0' => { id: line_item.id, quantity: 10 }
          }
        }

        expect(response.status).to eq(200)
        expect(json_response['line_items'].count).to eq(1)
        expect(json_response['line_items'].first['quantity']).to eq(10)
      end

      it 'adds an extra line item' do
        variant2 = create(:variant)
        api_put :update, id: order.to_param, order: {
          line_items: {
            '0' => { id: line_item.id, quantity: 10 },
            '1' => { variant_id: variant2.id, quantity: 1 }
          }
        }

        expect(response.status).to eq(200)
        expect(json_response['line_items'].count).to eq(2)
        expect(json_response['line_items'][0]['quantity']).to eq(10)
        expect(json_response['line_items'][1]['variant_id']).to eq(variant2.id)
        expect(json_response['line_items'][1]['quantity']).to eq(1)
      end

      it 'cannot change the price of an existing line item' do
        api_put :update, id: order.to_param, order: {
          line_items: {
            0 => { id: line_item.id, price: 0 }
          }
        }

        expect(response.status).to eq(200)
        expect(json_response['line_items'].count).to eq(1)
        expect(json_response['line_items'].first['price'].to_f).not_to eq(0)
        expect(json_response['line_items'].first['price'].to_f).to eq(line_item.variant.price)
      end

      it 'can add billing address' do
        api_put :update, id: order.to_param, order: { bill_address_attributes: billing_address }

        expect(order.reload.bill_address).not_to be_nil
      end

      it 'receives error message if trying to add billing address with errors' do
        billing_address[:firstname] = ''

        api_put :update, id: order.to_param, order: { bill_address_attributes: billing_address }

        expect(json_response['error']).not_to be_nil
        expect(json_response['errors']).not_to be_nil
        expect(json_response['errors']['bill_address.firstname'].first).to eq "can't be blank"
      end

      it 'can add shipping address' do
        expect(order.ship_address).to be_nil

        api_put :update, id: order.to_param, order: { ship_address_attributes: shipping_address }

        expect(order.reload.ship_address).not_to be_nil
      end

      it 'receives error message if trying to add shipping address with errors' do
        expect(order.ship_address).to be_nil
        shipping_address[:firstname] = ''

        api_put :update, id: order.to_param, order: { ship_address_attributes: shipping_address }

        expect(json_response['error']).not_to be_nil
        expect(json_response['errors']).not_to be_nil
        expect(json_response['errors']['ship_address.firstname'].first).to eq "can't be blank"
      end

      it 'can set the user_id for the order' do
        user = Spree.user_class.create
        api_post :update, id: order.to_param, order: { user_id: user.id }
        expect(response.status).to eq 200
        expect(json_response['user_id']).to eq(user.id)
      end

      context 'order has shipments' do
        before { order.create_proposed_shipments }

        it 'clears out all existing shipments on line item udpate' do
          api_put :update, id: order.to_param, order: {
            line_items: {
              0 => { id: line_item.id, quantity: 10 }
            }
          }
          expect(order.reload.shipments).to be_empty
        end
      end

      context 'with a line item' do
        let(:order_with_line_items) do
          order = create(:order_with_line_items)
          create(:adjustment, order: order, adjustable: order)
          order
        end

        it 'can empty an order' do
          expect(order_with_line_items.adjustments.count).to eq(1)
          api_put :empty, id: order_with_line_items.to_param
          expect(response.status).to eq(204)
          order_with_line_items.reload
          expect(order_with_line_items.line_items).to be_empty
          expect(order_with_line_items.adjustments).to be_empty
        end

        it 'can list its line items with images' do
          create_image(order.line_items.first.variant, image('thinking-cat.jpg'))

          api_get :show, id: order.to_param

          expect(json_response['line_items'].first['variant']).to have_attributes([:images])
        end

        it 'lists variants product id' do
          api_get :show, id: order.to_param

          expect(json_response['line_items'].first['variant']).to have_attributes([:product_id])
        end

        it 'includes the tax_total in the response' do
          api_get :show, id: order.to_param

          expect(json_response['included_tax_total']).to eq('0.0')
          expect(json_response['additional_tax_total']).to eq('0.0')
          expect(json_response['display_included_tax_total']).to eq('$0.00')
          expect(json_response['display_additional_tax_total']).to eq('$0.00')
        end

        it 'lists line item adjustments' do
          adjustment = create(:adjustment,
                              label: '10% off!',
                              order: order,
                              adjustable: order.line_items.first)
          adjustment.update_column(:amount, 5)
          api_get :show, id: order.to_param

          adjustment = json_response['line_items'].first['adjustments'].first
          expect(adjustment['label']).to eq('10% off!')
          expect(adjustment['amount']).to eq('5.0')
        end

        it 'lists payments source without gateway info' do
          order.payments.push payment = create(:payment)
          api_get :show, id: order.to_param

          source = json_response[:payments].first[:source]
          expect(source[:name]).to eq payment.source.name
          expect(source[:cc_type]).to eq payment.source.cc_type
          expect(source[:last_digits]).to eq payment.source.last_digits
          expect(source[:month].to_i).to eq payment.source.month
          expect(source[:year].to_i).to eq payment.source.year
          expect(source.key?(:gateway_customer_profile_id)).to be false
          expect(source.key?(:gateway_payment_profile_id)).to be false
        end

        context 'when in delivery' do
          let!(:shipping_method) do
            FactoryBot.create(:shipping_method).tap do |shipping_method|
              shipping_method.calculator.preferred_amount = 10
              shipping_method.calculator.save
            end
          end

          before do
            order.bill_address = FactoryBot.create(:address)
            order.ship_address = FactoryBot.create(:address)
            order.next!
            order.save
          end

          it 'includes the ship_total in the response' do
            api_get :show, id: order.to_param

            expect(json_response['ship_total']).to eq '10.0'
            expect(json_response['display_ship_total']).to eq '$10.00'
          end

          it 'returns available shipments for an order' do
            api_get :show, id: order.to_param
            expect(response.status).to eq(200)
            expect(json_response['shipments']).not_to be_empty
            shipment = json_response['shipments'][0]
            # Test for correct shipping method attributes
            # Regression test for #3206
            expect(shipment['shipping_methods']).not_to be_nil
            json_shipping_method = shipment['shipping_methods'][0]
            expect(json_shipping_method['id']).to eq(shipping_method.id)
            expect(json_shipping_method['name']).to eq(shipping_method.name)
            expect(json_shipping_method['code']).to eq(shipping_method.code)
            expect(json_shipping_method['zones']).not_to be_empty
            expect(json_shipping_method['shipping_categories']).not_to be_empty

            # Test for correct shipping rates attributes
            # Regression test for #3206
            expect(shipment['shipping_rates']).not_to be_nil
            shipping_rate = shipment['shipping_rates'][0]
            expect(shipping_rate['name']).to eq(json_shipping_method['name'])
            expect(shipping_rate['cost']).to eq('10.0')
            expect(shipping_rate['selected']).to be true
            expect(shipping_rate['display_cost']).to eq('$10.00')
            expect(shipping_rate['shipping_method_code']).to eq(json_shipping_method['code'])

            expect(shipment['stock_location_name']).not_to be_blank
            manifest_item = shipment['manifest'][0]
            expect(manifest_item['quantity']).to eq(1)
            expect(manifest_item['variant_id']).to eq(order.line_items.first.variant_id)
          end
        end
      end
    end

    context 'as an admin' do
      sign_in_as_admin!

      context 'with no orders' do
        before { Spree::Order.delete_all }

        it 'still returns a root :orders key' do
          api_get :index
          expect(json_response['orders']).to eq([])
        end
      end

      it 'responds with orders updated_at with miliseconds precision' do
        if ApplicationRecord.connection.adapter_name == 'Mysql2'
          skip 'MySQL does not support millisecond timestamps.'
        else
          skip 'Probable need to make it call as_json. See https://github.com/rails/rails/commit/0f33d70e89991711ff8b3dde134a61f4a5a0ec06'
        end

        api_get :index
        milisecond = order.updated_at.strftime('%L')
        updated_at = json_response['orders'].first['updated_at']
        expect(updated_at.split('T').last).to have_content(milisecond)
      end

      context 'caching enabled' do
        before do
          ActionController::Base.perform_caching = true
          create_list(:order, 3)
        end

        after { ActionController::Base.perform_caching = false }

        it 'returns unique orders' do
          api_get :index

          orders = json_response[:orders]
          expect(orders.count).to be >= 3
          expect(orders.map { |o| o[:id] }).to match_array Order.pluck(:id)
        end
      end

      it 'lists payments source with gateway info' do
        order.payments.push payment = create(:payment)
        api_get :show, id: order.to_param

        source = json_response[:payments].first[:source]
        expect(source[:name]).to eq payment.source.name
        expect(source[:cc_type]).to eq payment.source.cc_type
        expect(source[:last_digits]).to eq payment.source.last_digits
        expect(source[:month].to_i).to eq payment.source.month
        expect(source[:year].to_i).to eq payment.source.year
        expect(source[:gateway_customer_profile_id]).to eq payment.source.gateway_customer_profile_id
        expect(source[:gateway_payment_profile_id]).to eq payment.source.gateway_payment_profile_id
      end

      context 'with two orders' do
        before { create(:order) }

        it 'can view all orders' do
          api_get :index
          expect(json_response['orders'].first).to have_attributes(attributes)
          expect(json_response['count']).to eq(2)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(1)
        end

        # Test for #1763
        it 'can control the page size through a parameter' do
          api_get :index, per_page: 1
          expect(json_response['orders'].count).to eq(1)
          expect(json_response['orders'].first).to have_attributes(attributes)
          expect(json_response['count']).to eq(1)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(2)
        end
      end

      context 'search' do
        before do
          create(:order)
          Spree::Order.last.update_attribute(:email, 'spree@spreecommerce.com')
        end

        let(:expected_result) { Spree::Order.last }

        it 'can query the results through a parameter' do
          api_get :index, q: { email_cont: 'spree' }
          expect(json_response['orders'].count).to eq(1)
          expect(json_response['orders'].first).to have_attributes(attributes)
          expect(json_response['orders'].first['email']).to eq(expected_result.email)
          expect(json_response['count']).to eq(1)
          expect(json_response['current_page']).to eq(1)
          expect(json_response['pages']).to eq(1)
        end
      end

      context 'creation' do
        it 'can create an order without any parameters' do
          expect { api_post :create }.not_to raise_error
          expect(response.status).to eq(201)
          expect(json_response['state']).to eq('cart')
        end

        it 'can arbitrarily set the line items price' do
          api_post :create, order: {
            line_items: [{ price: 33.0, variant_id: variant.to_param, quantity: 5 }]
          }
          expect(response.status).to eq 201
          expect(Order.last.line_items.first.price.to_f).to eq(33.0)
        end

        it 'can set the user_id for the order' do
          user = Spree.user_class.create
          api_post :create, order: { user_id: user.id }
          expect(response.status).to eq 201
          expect(json_response['user_id']).to eq(user.id)
        end
      end

      context 'updating' do
        it 'can set the user_id for the order' do
          user = Spree.user_class.create
          api_post :update, id: order.number, order: { user_id: user.id }
          expect(response.status).to eq 200
          expect(json_response['user_id']).to eq(user.id)
        end
      end

      context 'can cancel an order' do
        before do
          order.completed_at = Time.current
          order.state = 'complete'
          order.shipment_state = 'ready'
          order.save!
        end

        specify do
          api_put :cancel, id: order.to_param
          expect(json_response['state']).to eq('canceled')
          expect(json_response['canceler_id']).to eq(current_api_user.id)
        end
      end

      context 'can approve an order' do
        before do
          order.completed_at = Time.current
          order.state = 'complete'
          order.shipment_state = 'ready'
          order.considered_risky = true
          order.save!
        end

        specify do
          api_put :approve, id: order.to_param
          order.reload
          expect(order.approver_id).to eq(current_api_user.id)
          expect(order.considered_risky).to eq(false)
        end
      end
    end

    context 'PUT remove_coupon_code' do
      let(:order) { create(:order_with_line_items) }

      it 'returns 404 status if promotion does not exist' do
        api_put :remove_coupon_code, id: order.number,
                                     order_token: order.token,
                                     coupon_code: 'example'

        expect(response.status).to eq 404
      end

      context 'order with discount promotion' do
        let!(:discount_promo_code) { 'discount' }
        let!(:discount_promotion) { create(:promotion_with_order_adjustment, code: discount_promo_code) }
        let(:order_with_discount_promotion) do
          create(:order_with_line_items, coupon_code: discount_promo_code).tap do |order|
            Spree::PromotionHandler::Coupon.new(order).apply
          end
        end

        it 'removes all order adjustments from order and return status 200' do
          expect(order_with_discount_promotion.reload.total.to_f).to eq 100.0

          api_put :remove_coupon_code, id: order_with_discount_promotion.number,
                                       order_token: order_with_discount_promotion.token,
                                       coupon_code: order_with_discount_promotion.coupon_code

          expect(response.status).to eq 200
          expect(json_response['success']).to eq Spree.t('adjustments_deleted')
          expect(order_with_discount_promotion.reload.total.to_f).to eq 110.0
        end
      end

      context 'order with line item discount promotion' do
        let!(:line_item_promo_code) { 'line_item_discount' }
        let!(:line_item_promotion) { create(:promotion_with_item_adjustment, code: line_item_promo_code) }
        let(:order_with_line_item_promotion) do
          create(:order_with_line_items, coupon_code: line_item_promo_code).tap do |order|
            Spree::PromotionHandler::Coupon.new(order).apply
          end
        end

        it 'removes line item adjustments from order and return status 200' do
          expect(order_with_line_item_promotion.reload.total.to_f).to eq 100.0

          api_put :remove_coupon_code, id: order_with_line_item_promotion.number,
                                       order_token: order_with_line_item_promotion.token,
                                       coupon_code: order_with_line_item_promotion.coupon_code

          expect(response.status).to eq 200
          expect(json_response['success']).to eq Spree.t('adjustments_deleted')
          expect(order_with_line_item_promotion.reload.total.to_f).to eq 110.0
        end

        it 'removes line item adjustments only for promotable line item' do
          order_with_line_item_promotion.line_items << create(:line_item, price: 100)
          order_with_line_item_promotion.update_with_updater!

          expect(order_with_line_item_promotion.reload.total.to_f).to eq 200.0

          api_put :remove_coupon_code, id: order_with_line_item_promotion.number,
                                       order_token: order_with_line_item_promotion.token,
                                       coupon_code: order_with_line_item_promotion.coupon_code

          expect(order_with_line_item_promotion.reload.total.to_f).to eq 210.0
        end
      end
    end
  end
end
