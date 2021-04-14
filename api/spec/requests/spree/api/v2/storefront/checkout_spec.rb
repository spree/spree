require 'spec_helper'

describe 'API V2 Storefront Checkout Spec', type: :request do
  let(:default_currency) { 'USD' }
  let(:store) { create(:store, default_currency: default_currency) }
  let(:currency) { store.default_currency }
  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, store: store, currency: currency) }
  let(:payment) { create(:payment, amount: order.total, order: order) }
  let(:shipment) { create(:shipment, order: order) }

  let(:address) do
    {
      firstname: 'John',
      lastname: 'Doe',
      address1: '7735 Old Georgetown Road',
      city: 'Bethesda',
      phone: '3014445002',
      zipcode: '20814',
      state_id: state.id,
      country_iso: country.iso
    }
  end

  let(:payment_source_attributes) do
    {
      number: '4111111111111111',
      month: 1.month.from_now.month,
      year: 1.month.from_now.year,
      verification_value: '123',
      name: 'Spree Commerce'
    }
  end
  let(:payment_params) do
    {
      order: {
        payments_attributes: [
          {
            payment_method_id: payment_method.id
          }
        ]
      },
      payment_source: {
        payment_method.id.to_s => payment_source_attributes
      }
    }
  end

  include_context 'API v2 tokens'

  describe 'checkout#next' do
    let(:execute) { patch '/api/v2/storefront/checkout/next', headers: headers }

    shared_examples 'perform next' do
      context 'without line items' do
        before do
          order.line_items.destroy_all
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'cannot transition to address without a line item' do
          expect(json_response['error']).to include(Spree.t(:there_are_no_items_for_this_order))
        end
      end

      context 'with line_items and email' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'can transition an order to the next state' do
          expect(order.reload.state).to eq('address')
          expect(json_response['data']).to have_attribute(:state).with_value('address')
        end
      end

      context 'without payment info' do
        before do
          order.update_column(:state, 'payment')
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to include(Spree.t(:no_payment_found))
        end

        it 'doesnt advance pass payment state' do
          expect(order.reload.state).to eq('payment')
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform next'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform next'
    end
  end

  describe 'checkout#advance' do
    let(:execute) { patch '/api/v2/storefront/checkout/advance', headers: headers }

    shared_examples 'perform advance' do
      before do
        order.update_column(:state, 'payment')
      end

      context 'with payment data' do
        before do
          payment
          execute
        end

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'advances an order till complete or confirm step' do
          expect(order.reload.state).to eq('confirm')
          expect(json_response['data']).to have_attribute(:state).with_value('confirm')
        end
      end

      context 'without payment data' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'doesnt advance pass payment state' do
          expect(order.reload.state).to eq('payment')
          expect(json_response['data']).to have_attribute(:state).with_value('payment')
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform advance'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform advance'
    end
  end

  describe 'checkout#complete' do
    let(:execute) { patch '/api/v2/storefront/checkout/complete', headers: headers }

    shared_examples 'perform complete' do
      before do
        order.update_column(:state, 'confirm')
      end

      context 'with payment data' do
        before do
          payment
          shipment
          execute
        end

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'completes an order' do
          expect(order.reload.state).to eq('complete')
          expect(order.completed_at).not_to be_nil
          expect(json_response['data']).to have_attribute(:state).with_value('complete')
        end
      end

      context 'without payment data' do
        before { execute }

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to include(Spree.t(:no_payment_found))
        end

        it 'doesnt completes an order' do
          expect(order.reload.state).not_to eq('complete')
          expect(order.completed_at).to be_nil
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform complete'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform complete'
    end
  end

  describe 'checkout#update' do
    let!(:country_zone) { create(:zone, name: 'CountryZone') }
    let!(:state)        { create(:state) }
    let!(:country)      { state.country }
    let!(:stock_location) { create(:stock_location) }

    let!(:shipping_method) { create(:shipping_method, zones: [country_zone]) }
    let!(:payment_method)  { create(:credit_card_payment_method) }

    let(:execute) { patch '/api/v2/storefront/checkout', params: params, headers: headers }

    include_context 'creates order with line item'

    before do
      allow_any_instance_of(Spree::PaymentMethod).to receive(:source_required?).and_return(false)
      allow_any_instance_of(Spree::Order).to receive_messages(confirmation_required?: true)
      allow_any_instance_of(Spree::Order).to receive_messages(payment_required?: true)
    end

    shared_examples 'perform update' do
      context 'addresses' do
        let(:params) do
          {
            order: {
              bill_address_attributes: address,
              ship_address_attributes: address
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates addresses' do
          order.reload
          expect(order.bill_address).not_to be_nil
          expect(order.ship_address).not_to be_nil
          expect(order.bill_address.firstname).to eq address[:firstname]
          expect(order.bill_address.lastname).to eq address[:lastname]
          expect(order.bill_address.address1).to eq address[:address1]
          expect(order.bill_address.city).to eq address[:city]
          expect(order.bill_address.phone).to eq address[:phone]
          expect(order.bill_address.zipcode).to eq address[:zipcode]
          expect(order.bill_address.state_id).to eq address[:state_id]
          expect(order.bill_address.country.iso).to eq address[:country_iso]
        end
      end

      context 'shipment' do
        let!(:default_selected_shipping_rate_id) { shipment.selected_shipping_rate_id }
        let(:new_selected_shipping_rate_id) { Spree::ShippingRate.last.id }
        let!(:shipping_method) { shipment.shipping_method }
        let!(:second_shipping_method) { create(:shipping_method, name: 'Fedex') }

        let(:params) do
          {
            order: {
              shipments_attributes: [
                { selected_shipping_rate_id: new_selected_shipping_rate_id, id: shipment.id }
              ]
            }
          }
        end

        before do
          shipment
          shipment.add_shipping_method(second_shipping_method)
          execute
        end

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates shipment' do
          shipment.reload
          expect(shipment.shipping_rates.count).to eq(2)
          expect(shipment.selected_shipping_rate_id).to eq(new_selected_shipping_rate_id)
          expect(shipment.selected_shipping_rate_id).not_to eq(default_selected_shipping_rate_id)
          expect(shipment.shipping_method).to eq(second_shipping_method)
        end
      end

      context 'payment' do
        context 'payment method' do
          let(:params) do
            {
              order: {
                payments_attributes: [
                  {
                    payment_method_id: payment_method.id
                  }
                ]
              }
            }
          end

          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'updates payment method' do
            expect(order.payments).not_to be_empty
            expect(order.payments.first.payment_method_id).to eq payment_method.id
          end
        end

        context 'payment source' do
          let(:params) { payment_params }

          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'updates payment method with source' do
            expect(order.payments).not_to be_empty
            expect(order.payments.last.source.name).to eq('Spree Commerce')
            expect(order.payments.last.source.last_digits).to eq('1111')
          end
        end

        context 'when the gateway rejects the payment source' do
          let(:params) { payment_params }

          before do
            allow_any_instance_of(Spree::Order).to receive(:update_from_params).and_raise(Spree::Core::GatewayError.new('Card declined'))
            execute
          end

          it_behaves_like 'returns 422 HTTP status'
        end
      end

      context 'special instructions' do
        let(:params) do
          {
            order: {
              special_instructions: "Don't drop it"
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates the special instructions' do
          expect(order.reload.special_instructions).to eq("Don't drop it")
        end

        it 'returns updated special instructions' do
          expect(json_response['data']).to have_attribute(:special_instructions).with_value("Don't drop it")
        end
      end

      context 'email' do
        let(:params) do
          {
            order: {
              email: 'guest@spreecommerce.org'
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates email' do
          expect(order.reload.email).to eq('guest@spreecommerce.org')
        end

        it 'returns updated email' do
          expect(json_response['data']).to have_attribute(:email).with_value('guest@spreecommerce.org')
        end
      end

      context 'with invalid params' do
        let(:params) do
          {
            order: {
              email: 'wrong_email'
            }
          }
        end

        before do
          order.update_column(:state, 'delivery')
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to eq('Email is invalid')
        end

        it 'returns validation errors' do
          expect(json_response['errors']).to eq('email' => ['is invalid'])
        end
      end

      context 'without order' do
        let(:params) { {} }

        it_behaves_like 'no current order'
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform update'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform update'
    end
  end

  describe 'checkout#add_store_credit' do
    let(:order_total) { 500.00 }
    let(:params) { { order_token: order.token } }
    let(:execute) { post '/api/v2/storefront/checkout/add_store_credit', params: params, headers: headers }

    before do
      create(:store_credit_payment_method)
      execute
    end

    context 'for guest or user without store credit' do
      let!(:order) { create(:order, total: order_total) }

      it_behaves_like 'returns 422 HTTP status'
    end

    context 'for user with store credits' do
      let!(:store_credit) { create(:store_credit, amount: order_total) }
      let!(:order) { create(:order, user: store_credit.user, total: order_total) }

      shared_examples 'valid payload' do |amount|
        it 'returns StoreCredit payment' do
          expect(json_response['data']).to have_relationship(:payments)
          payment = Spree::Payment.find(json_response['data']['relationships']['payments']['data'][0]['id'].to_i)
          expect(payment.amount).to eq amount
          expect(payment.payment_method.class).to eq Spree::PaymentMethod::StoreCredit
        end
      end

      context 'with no amount param' do
        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'valid payload', 500.0
      end

      context 'with amount params requested' do
        let(:requested_amount) { 300.0 }
        let(:params) { { order_token: order.token, amount: requested_amount } }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'valid payload', 300.0
      end

      context 'with option include' do
        let!(:payment) { Spree::Payment.all.first }

        context 'payments.source' do
          let(:execute) { post '/api/v2/storefront/checkout/add_store_credit?include=payments.source', params: params, headers: headers }

          it 'return relationship with store_credit' do
            expect(json_response['included'][0]).to have_type('store_credit')

            expect(json_response['included'][0]).to have_attribute(:amount).with_value(payment.source.amount.to_s)
            expect(json_response['included'][0]).to have_attribute(:amount_used).with_value(payment.source.amount_used.to_s)
            expect(json_response['included'][0]).to have_attribute(:created_at)

            expect(json_response['included'][0]).to have_relationship(:category)
            expect(json_response['included'][0]).to have_relationship(:store_credit_events)
            expect(json_response['included'][0]).to have_relationship(:credit_type)
          end
        end

        context 'payments.payment_method' do
          let(:execute) { post '/api/v2/storefront/checkout/add_store_credit?include=payments.payment_method', params: params, headers: headers }

          it 'return relationship with payment_method' do
            expect(json_response['included'][0]).to have_type('payment_method')

            expect(json_response['included'][0]).to have_attribute(:type).with_value(payment.payment_method.type)
            expect(json_response['included'][0]).to have_attribute(:name).with_value(payment.payment_method.name)
            expect(json_response['included'][0]).to have_attribute(:description).with_value(payment.payment_method.description)

            expect(json_response['included'][1]).to have_relationship(:source)
            expect(json_response['included'][1]).to have_relationship(:payment_method)
          end
        end
      end
    end
  end

  describe 'checkout#remove_store_credit' do
    let(:order_total) { 500.00 }
    let(:params) { { order_token: order.token, include: 'payments', fields: { payment: 'state' } } }
    let(:execute) { post '/api/v2/storefront/checkout/remove_store_credit', params: params, headers: headers }
    let!(:store_credit) { create(:store_credit, amount: order_total) }
    let!(:order) { create(:order, user: store_credit.user, total: order_total) }

    before do
      create(:store_credit_payment_method)
      Spree::Checkout::AddStoreCredit.call(order: order)
      execute
    end

    it_behaves_like 'returns 200 HTTP status'

    it 'returns no valid StoreCredit payment' do
      expect(json_response['included'].empty?).to eq true
    end
  end

  describe 'checkout#payment_methods' do
    let(:execute) { get '/api/v2/storefront/checkout/payment_methods', headers: headers }
    let!(:payment_method) { create(:credit_card_payment_method) }
    let(:payment_methods) { order.available_payment_methods }

    shared_examples 'returns a list of available payment methods' do
      before { execute }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns valid payment methods JSON' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data'][0]).to have_id(payment_method.id.to_s)
        expect(json_response['data'][0]).to have_type('payment_method')
        expect(json_response['data'][0]).to have_attribute(:name).with_value(payment_method.name)
        expect(json_response['data'][0]).to have_attribute(:description).with_value(payment_method.description)
        expect(json_response['data'][0]).to have_attribute(:type).with_value(payment_method.type)
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'returns a list of available payment methods'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'returns a list of available payment methods'
    end
  end

  describe 'checkout#shipping_rates' do
    let(:execute) { get '/api/v2/storefront/checkout/shipping_rates', headers: headers }

    let(:country) { Spree::Country.default }
    let(:zone) { create(:zone, name: 'US') }
    let(:shipping_method) { create(:shipping_method) }
    let(:address) { create(:address, country: country) }

    let(:shipment) { order.shipments.first }
    let(:shipping_rate) { shipment.selected_shipping_rate }

    shared_examples 'returns a list of shipments with shipping rates' do
      before do
        order.shipping_address = address
        order.save!
        zone.countries << country
        shipping_method.zones = [zone]
        order.create_proposed_shipments
        execute
        order.reload
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns valid shipments JSON' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data'].size).to eq(order.shipments.count)
        expect(json_response['data'][0]).to have_id(shipment.id.to_s)
        expect(json_response['data'][0]).to have_type('shipment')
        expect(json_response['data'][0]).to have_relationships(:shipping_rates)
        expect(json_response['included']).to be_present
        expect(json_response['included'].size).to eq(shipment.shipping_rates.count + 1)
        shipment.shipping_rates.each do |shipping_rate|
          expect(json_response['included']).to include(have_type('shipping_rate').and have_id(shipping_rate.id.to_s))
        end
        expect(json_response['included'][0]).to have_id(shipping_rate.id.to_s)
        expect(json_response['included'][0]).to have_type('shipping_rate')
        expect(json_response['included'][0]).to have_attribute(:name).with_value(shipping_method.name)
        expect(json_response['included'][0]).to have_attribute(:final_price).with_value(shipping_rate.final_price.to_s)
        expect(json_response['included'][0]).to have_attribute(:display_final_price).with_value(shipping_rate.display_final_price.to_s)
        expect(json_response['included'][0]).to have_attribute(:cost).with_value(shipping_rate.cost.to_s)
        expect(json_response['included'][0]).to have_attribute(:display_cost).with_value(shipping_rate.display_cost.to_s)
        expect(json_response['included'][0]).to have_attribute(:tax_amount).with_value(shipping_rate.tax_amount.to_s)
        expect(json_response['included'][0]).to have_attribute(:display_tax_amount).with_value(shipping_rate.display_tax_amount.to_s)
        expect(json_response['included'][0]).to have_attribute(:shipping_method_id).with_value(shipping_method.id)
        expect(json_response['included'][0]).to have_attribute(:selected).with_value(shipping_rate.selected)
        expect(json_response['included'][0]).to have_attribute(:free).with_value(shipping_rate.free?)

        expect(json_response['included']).to include(have_type('stock_location').and have_id(shipment.stock_location_id.to_s))
        expect(json_response['included']).to include(have_type('stock_location').and have_attribute(:name).with_value(shipment.stock_location.name))
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

  describe 'full checkout flow' do
    let!(:country) { create(:country) }
    let(:state) { create(:state, country: country) }
    let!(:shipping_method) do
      create(:shipping_method).tap do |shipping_method|
        shipping_method.zones = [zone]
      end
    end
    let!(:zone) { create(:zone) }
    let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
    let!(:payment_method) { create(:credit_card_payment_method) }

    let(:customer_params) do
      {
        order: {
          email: 'new@customer.org',
          bill_address_attributes: address,
          ship_address_attributes: address
        }
      }
    end

    let(:shipment_params) do
      {
        order: {
          shipments_attributes: [
            { selected_shipping_rate_id: shipping_rate_id, id: shipment_id }
          ]
        }
      }
    end

    let(:shipping_rate_id) do
      json_response['data'].first['relationships']['shipping_rates']['data'].first['id']
    end
    let(:shipment_id) { json_response['data'].first['id'] }

    shared_examples 'transitions through checkout from start to finish' do
      before do
        zone.countries << country
        shipping_method.zones = [zone]
      end

      it 'completes checkout' do
        # we need to set customer information (email, billing & shipping address)
        patch '/api/v2/storefront/checkout', params: customer_params, headers: headers
        expect(response.status).to eq(200)

        # getting back shipping rates
        get '/api/v2/storefront/checkout/shipping_rates', headers: headers
        expect(response.status).to eq(200)

        # selecting shipping method
        patch '/api/v2/storefront/checkout', params: shipment_params, headers: headers
        expect(response.status).to eq(200)

        # getting back list of available payment methods
        get '/api/v2/storefront/checkout/payment_methods', headers: headers
        expect(response.status).to eq(200)
        expect(json_response['data'].first['id']).to eq(payment_method.id.to_s)

        # creating a CC for selected payment method
        patch '/api/v2/storefront/checkout', params: payment_params, headers: headers
        expect(response.status).to eq(200)

        # complete the checkout
        patch '/api/v2/storefront/checkout/complete', headers: headers
        expect(response.status).to eq(200)
        expect(order.reload.completed_at).not_to be_nil
        expect(order.state).to eq('complete')
        expect(order.payments.valid.first.payment_method).to eq(payment_method)
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'transitions through checkout from start to finish'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'transitions through checkout from start to finish'
    end
  end
end
