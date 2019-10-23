require 'spec_helper'

module Spree
  describe Api::V1::CheckoutsController, type: :controller do
    render_views

    shared_examples_for 'action which loads order using load_order_with_lock' do
      before do
        allow(controller).to receive(:load_order).with(true).and_return(true)
      end

      it 'invokes load_order_with_lock' do
        expect(controller).to receive(:load_order_with_lock).once
      end

      it 'invokes load_order' do
        expect(controller).to receive(:load_order).with(true).once.and_return(true)
      end

      context 'ensure no double_render_error' do
        before do
          def controller.load_order(*)
            respond_with(@order, default_template: 'spree/api/v1/orders/show', status: 200)
          end
        end

        it 'does not generate double_render_error' do
          expect(response).to be_successful
        end
      end

      after do
        send_request
      end
    end

    before do
      stub_authentication!
      Spree::Config[:track_inventory_levels] = false
      country_zone = create(:zone, name: 'CountryZone')
      @state = create(:state)
      @country = @state.country
      country_zone.members.create(zoneable: @country)
      create(:stock_location)

      @shipping_method = create(:shipping_method, zones: [country_zone])
      @payment_method = create(:credit_card_payment_method)
    end

    after do
      Spree::Config[:track_inventory_levels] = true
    end

    context "PUT 'update'" do
      let(:order) do
        order = create(:order_with_line_items)
        # Order should be in a pristine state
        # Without doing this, the order may transition from 'cart' straight to 'delivery'
        Spree::ShippingRate.where(shipment_id: order.shipment_ids).delete_all
        order.shipments.delete_all
        order
      end

      before do
        allow_any_instance_of(Order).to receive_messages(confirmation_required?: true)
        allow_any_instance_of(Order).to receive_messages(payment_required?: true)
      end

      it 'transitions a recently created order from cart to address' do
        expect(order.state).to eq 'cart'
        expect(order.email).not_to be_nil
        api_put :update, id: order.to_param, order_token: order.token
        expect(order.reload.state).to eq 'address'
      end

      it 'transitions a recently created order from cart to address with order token in header' do
        expect(order.state).to eq 'cart'
        expect(order.email).not_to be_nil
        request.headers['X-Spree-Order-Token'] = order.token
        api_put :update, id: order.to_param
        expect(order.reload.state).to eq 'address'
      end

      it 'can take line_items_attributes as a parameter' do
        line_item = order.line_items.first
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { line_items_attributes: { 0 => { id: line_item.id, quantity: 1 } } }
        expect(response.status).to eq(200)
        expect(order.reload.state).to eq 'address'
      end

      it 'can take line_items as a parameter' do
        line_item = order.line_items.first
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { line_items: { 0 => { id: line_item.id, quantity: 1 } } }
        expect(response.status).to eq(200)
        expect(order.reload.state).to eq 'address'
      end

      it 'will return an error if the order cannot transition' do
        skip 'not sure if this test is valid'
        order.bill_address = nil
        order.save
        order.update_column(:state, 'address')
        api_put :update, id: order.to_param, order_token: order.token
        # Order has not transitioned
        expect(response.status).to eq(422)
      end

      context 'transitioning to delivery' do
        before do
          order.update_column(:state, 'address')
        end

        let(:address) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '7735 Old Georgetown Road',
            city: 'Bethesda',
            phone: '3014445002',
            zipcode: '20814',
            state_id: @state.id,
            country_id: @country.id
          }
        end

        it 'can update addresses and transition from address to delivery' do
          api_put :update,
                  id: order.to_param, order_token: order.token,
                  order: {
                    bill_address_attributes: address,
                    ship_address_attributes: address
                  }
          expect(json_response['state']).to eq('delivery')
          expect(json_response['bill_address']['firstname']).to eq('John')
          expect(json_response['ship_address']['firstname']).to eq('John')
          expect(response.status).to eq(200)
        end

        # Regression Spec for #5389 & #5880
        it 'can update addresses but not transition to delivery w/o shipping setup' do
          Spree::ShippingMethod.destroy_all
          api_put :update,
                  id: order.to_param, order_token: order.token,
                  order: {
                    bill_address_attributes: address,
                    ship_address_attributes: address
                  }
          expect(json_response['error']).to eq(I18n.t(:could_not_transition, scope: 'spree.api.order'))
          expect(response.status).to eq(422)
        end

        # Regression test for #4498
        it 'does not contain duplicate variant data in delivery return' do
          api_put :update,
                  id: order.to_param, order_token: order.token,
                  order: {
                    bill_address_attributes: address,
                    ship_address_attributes: address
                  }
          # Shipments manifests should not return the ENTIRE variant
          # This information is already present within the order's line items
          expect(json_response['shipments'].first['manifest'].first['variant']).to be_nil
          expect(json_response['shipments'].first['manifest'].first['variant_id']).not_to be_nil
        end
      end

      it 'can update shipping method and transition from delivery to payment' do
        order.update_column(:state, 'delivery')
        shipment = create(:shipment, order: order)
        shipment.refresh_rates
        shipping_rate = shipment.shipping_rates.where(selected: false).first
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { shipments_attributes: { '0' => { selected_shipping_rate_id: shipping_rate.id, id: shipment.id } } }
        expect(response.status).to eq(200)
        # Find the correct shipment...
        json_shipment = json_response['shipments'].detect { |s| s['id'] == shipment.id }
        # Find the correct shipping rate for that shipment...
        json_shipping_rate = json_shipment['shipping_rates'].detect { |sr| sr['id'] == shipping_rate.id }
        # ... And finally ensure that it's selected
        expect(json_shipping_rate['selected']).to be true
        # Order should automatically transfer to payment because all criteria are met
        expect(json_response['state']).to eq('payment')
      end

      it 'can update payment method and transition from payment to confirm' do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:source_required?).and_return(false)
        order.update_column(:state, 'payment')
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { payments_attributes: [{ payment_method_id: @payment_method.id }] }
        expect(json_response['state']).to eq('confirm')
        expect(json_response['payments'][0]['payment_method']['name']).to eq(@payment_method.name)
        expect(json_response['payments'][0]['amount']).to eq(order.total.to_s)
        expect(response.status).to eq(200)
      end

      it 'can update payment method with source and transition from payment to confirm' do
        order.update_column(:state, 'payment')
        source_attributes = {
          number: '4111111111111111',
          month: 1.month.from_now.month,
          year: 1.month.from_now.year,
          verification_value: '123',
          name: 'Spree Commerce'
        }

        api_put :update, id: order.to_param, order_token: order.token,
                         order: { payments_attributes: [{ payment_method_id: @payment_method.id.to_s, source_attributes: source_attributes }] }
        expect(json_response['payments'][0]['payment_method']['name']).to eq(@payment_method.name)
        expect(json_response['payments'][0]['amount']).to eq(order.total.to_s)
        expect(response.status).to eq(200)
      end

      it 'returns errors when source is missing attributes' do
        order.update_column(:state, 'payment')
        api_put :update, id: order.to_param, order_token: order.token,
                         order: {
                           payments_attributes: [{ payment_method_id: @payment_method.id }]
                         },
                         payment_source: {
                           @payment_method.id.to_s => { name: 'Spree' }
                         }

        expect(response.status).to eq(422)
        cc_errors = json_response['errors']['payments.Credit Card']
        expect(cc_errors).to include("Number can't be blank")
        expect(cc_errors).to include('Month is not a number')
        expect(cc_errors).to include('Year is not a number')
        expect(cc_errors).to include("Verification Value can't be blank")
      end

      it 'allow users to reuse a credit card' do
        order.update_column(:state, 'payment')
        credit_card = create(:credit_card, user_id: order.user_id, payment_method_id: @payment_method.id)

        api_put :update, id: order.to_param, order_token: order.token,
                         order: { existing_card: credit_card.id }

        expect(response.status).to eq 200
        expect(order.credit_cards).to match_array [credit_card]
      end

      it 'can transition from confirm to complete' do
        order.update_columns(state: 'confirm')
        allow_any_instance_of(Spree::Order).to receive_messages(payment_required?: false)
        api_put :update, id: order.to_param, order_token: order.token
        expect(json_response['state']).to eq('complete')
        expect(response.status).to eq(200)
      end

      it 'can transition from confirm to delivery wtih logging state changes' do
        order.update_columns(state: 'confirm')
        allow_any_instance_of(Spree::Order).to receive_messages(payment_required?: false)
        api_put :update, state: 'delivery', id: order.to_param, order_token: order.token
        expect(response.status).to eq(200)
        expect(order.state_changes.count).to eq 3
      end

      it 'prevent normal user from updating completed order' do
        order.update_columns(completed_at: Time.current, state: 'complete')
        api_put :update, id: order.to_param, order_token: order.token
        assert_unauthorized!
      end

      # Regression test for #3784
      it 'can update the special instructions for an order' do
        instructions = "Don't drop it. (Please)"
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { special_instructions: instructions }
        expect(json_response['special_instructions']).to eql(instructions)
      end

      context 'as an admin' do
        sign_in_as_admin!
        it 'can assign a user to the order' do
          user = create(:user)
          # Need to pass email as well so that validations succeed
          api_put :update, id: order.to_param, order_token: order.token,
                           order: { user_id: user.id, email: 'guest@spreecommerce.org' }
          expect(response.status).to eq(200)
          expect(json_response['user_id']).to eq(user.id)
        end
      end

      it 'can assign an email to the order' do
        api_put :update, id: order.to_param, order_token: order.token,
                         order: { email: 'guest@spreecommerce.org' }
        expect(json_response['email']).to eq('guest@spreecommerce.org')
        expect(response.status).to eq(200)
      end

      it 'can apply a coupon code to an order' do
        order.update_column(:state, 'payment')
        expect(PromotionHandler::Coupon).to receive(:new).with(order).and_call_original
        expect_any_instance_of(PromotionHandler::Coupon).to receive(:apply).and_return(coupon_applied?: true)
        api_put :update, id: order.to_param, order_token: order.token, order: { coupon_code: 'foobar' }
      end

      def send_request
        api_put :update, id: order.to_param, order_token: order.token
      end

      it_behaves_like 'action which loads order using load_order_with_lock'
    end

    context "PUT 'next'" do
      let!(:order) { create(:order_with_line_items) }

      it 'cannot transition to address without a line item' do
        order.line_items.delete_all
        order.update_column(:email, 'spree@example.com')
        api_put :next, id: order.to_param, order_token: order.token
        expect(response.status).to eq(422)
        expect(json_response['errors']['base']).to include(Spree.t(:there_are_no_items_for_this_order))
      end

      it 'can transition an order to the next state' do
        order.update_column(:email, 'spree@example.com')

        api_put :next, id: order.to_param, order_token: order.token
        expect(response.status).to eq(200)
        expect(json_response['state']).to eq('address')
      end

      it 'cannot transition if order email is blank' do
        order.update_columns(
          state: 'address',
          email: nil
        )

        api_put :next, id: order.to_param, order_token: order.token
        expect(response.status).to eq(422)
        expect(json_response['error']).to match(/could not be transitioned/)
      end

      it 'cannot transition if any line_item becomes unavailable' do
        allow_any_instance_of(Order).to receive(:insufficient_stock_lines).and_return(order.line_items)
        api_put :next, id: order.to_param, order_token: order.token
        expect(response.status).to eq(422)
        expect(json_response['error']).to match(Spree.t(:insufficient_quantity, scope: [:api, :order]))
      end

      it 'doesnt advance payment state if order has no payment' do
        order.update_column(:state, 'payment')
        api_put :next, id: order.to_param, order_token: order.token, order: {}
        expect(json_response['errors']['base']).to include(Spree.t(:no_payment_found))
      end

      def send_request
        api_put :next, id: order.to_param, order_token: order.token
      end

      it_behaves_like 'action which loads order using load_order_with_lock'
    end

    context "PUT 'advance'" do
      let!(:order) { create(:order_with_line_items) }

      it 'continues to advance advances an order while it can move forward' do
        expect_any_instance_of(Spree::Order).to receive(:next).exactly(3).times.and_return(true, true, false)
        api_put :advance, id: order.to_param, order_token: order.token
      end

      it 'returns the order' do
        api_put :advance, id: order.to_param, order_token: order.token
        expect(json_response['id']).to eq(order.id)
      end

      def send_request
        api_put :advance, id: order.to_param, order_token: order.token
      end

      it_behaves_like 'action which loads order using load_order_with_lock'
    end
  end
end
