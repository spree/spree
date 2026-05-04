require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order, store: store, state: 'cart') }

  describe 'GET #index' do
    subject { get :index, params: {}, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns orders list' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['id']).to eq(order.prefixed_id)
    end

    it 'includes admin-only fields' do
      subject

      data = json_response['data'].first
      expect(data).to have_key('considered_risky')
    end

    it 'returns pagination metadata' do
      subject

      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    context 'with ransack filtering' do
      let!(:completed_order) { create(:completed_order_with_totals, store: store) }

      it 'filters by state' do
        get :index, params: { q: { state_eq: 'complete' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['id']).to eq(completed_order.prefixed_id)
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns 401 unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
      expect(json_response['number']).to eq(order.number)
    end

    it 'includes admin-only fields' do
      subject

      expect(json_response).to have_key('considered_risky')
      expect(json_response).to have_key('internal_note')
    end

    context 'with non-existent order' do
      it 'returns 404' do
        get :show, params: { id: 'or_nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: create_params, as: :json }

    before { request.headers.merge!(headers) }

    let(:create_params) { { email: 'test@example.com' } }

    it 'creates a draft order' do
      expect { subject }.to change(Spree::Order, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['email']).to eq('test@example.com')
    end

    context 'with user assignment via user_id' do
      let(:customer) { create(:user) }
      let(:create_params) { { user_id: customer.prefixed_id } }

      it 'creates order assigned to the user' do
        subject

        expect(response).to have_http_status(:created)
        created_order = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created_order.user).to eq(customer)
      end
    end

    context 'with customer assignment via customer_id' do
      let(:customer) { create(:user) }
      let(:create_params) { { customer_id: customer.prefixed_id } }

      it 'creates order assigned to the customer' do
        subject

        expect(response).to have_http_status(:created)
        created_order = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created_order.user).to eq(customer)
      end
    end

    context 'with inline items' do
      let(:variant) { create(:variant, prices: [build(:price, currency: 'USD', amount: 19.99)]) }
      let(:create_params) do
        {
          email: 'test@example.com',
          items: [{ variant_id: variant.prefixed_id, quantity: 3 }]
        }
      end

      it 'creates the order with the line items' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.line_items.count).to eq(1)
        expect(created.line_items.first.variant).to eq(variant)
        expect(created.line_items.first.quantity).to eq(3)
      end
    end

    context 'with items and shipping address (one-shot draft order)' do
      let(:country) { @default_country }
      let(:state)   { country.states.first || create(:state, country: country) }
      let!(:zone)   { create(:zone) }
      let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
      let!(:shipping_method) do
        create(:shipping_method, zones: [zone]).tap do |sm|
          sm.calculator.preferred_amount = 5
          sm.calculator.save
        end
      end
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

      let(:product) { create(:product_in_stock, stores: [store]) }
      let(:variant) { product.default_variant }

      let(:create_params) do
        {
          email: 'test@example.com',
          items: [{ variant_id: variant.prefixed_id, quantity: 2 }],
          shipping_address: {
            firstname: 'Jane', lastname: 'Doe',
            address1: '350 Fifth Avenue', city: 'New York',
            zipcode: '10118', phone: '555-555-0199',
            country_id: country.id, state_id: state.id
          }
        }
      end

      it 'creates fulfillments and returns delivery_total in the response' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])

        expect(created.shipments).not_to be_empty
        expect(created.shipments.first.shipping_rates).not_to be_empty
        expect(created.shipments.first.selected_shipping_rate).to be_present
        expect(created.shipment_total).to eq(5)
        expect(created.total).to eq(created.item_total + created.shipment_total + created.adjustment_total)

        expect(json_response['delivery_total']).to eq('5.0')
        expect(json_response['total']).to eq(created.total.to_s)
      end
    end

    context 'with use_customer_default_address' do
      let(:address) { create(:address) }
      let(:customer) { create(:user, bill_address: address, ship_address: address) }
      let(:create_params) do
        {
          customer_id: customer.prefixed_id,
          use_customer_default_address: true
        }
      end

      it 'copies the customer default addresses onto the order' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.bill_address).to be_present
        expect(created.ship_address).to be_present
        expect(created.bill_address.address1).to eq(address.address1)
      end
    end

    context 'with metadata' do
      let(:create_params) do
        {
          email: 'test@example.com',
          metadata: { external_reference: 'subscription-12345', source: 'recurring' }
        }
      end

      it 'stores metadata on the order' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.metadata['external_reference']).to eq('subscription-12345')
        expect(created.metadata['source']).to eq('recurring')
      end
    end

    context 'creates order with status draft' do
      it 'sets status to draft' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.status).to eq('draft')
        expect(created.completed_at).to be_nil
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { id: order.prefixed_id, email: 'updated@example.com' }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['email']).to eq('updated@example.com')
    end

    context 'with customer assignment via customer_id' do
      let(:customer) { create(:user) }

      it 'assigns the customer' do
        patch :update, params: { id: order.prefixed_id, customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.user).to eq(customer)
        expect(json_response['customer_id']).to eq(customer.prefixed_id)
      end
    end

    context 'with customer reassignment via customer_id' do
      let(:original_customer) { create(:user) }
      let(:new_customer) { create(:user) }
      let!(:order) { create(:order, store: store, state: 'cart', user: original_customer) }

      it 'reassigns to the new customer' do
        patch :update, params: { id: order.prefixed_id, customer_id: new_customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.user).to eq(new_customer)
      end
    end

    context 'with tags' do
      it 'sets tags on a previously untagged order' do
        patch :update, params: { id: order.prefixed_id, tags: ['VIP'] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.tag_list).to contain_exactly('VIP')
        expect(json_response['tags']).to contain_exactly('VIP')
      end

      it 'replaces existing tags' do
        order.update!(tag_list: ['old'])
        patch :update, params: { id: order.prefixed_id, tags: %w[new fresh] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.tag_list).to contain_exactly('new', 'fresh')
      end

      it 'clears tags when given an empty array' do
        order.update!(tag_list: ['old'])
        patch :update, params: { id: order.prefixed_id, tags: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.tag_list).to be_empty
      end

      it 'leaves tags untouched when key is omitted' do
        order.update!(tag_list: ['VIP'])
        patch :update, params: { id: order.prefixed_id, email: 'nochange@example.com' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.tag_list).to contain_exactly('VIP')
      end
    end

    context 'adding items to a draft order with a shipping address' do
      let(:country) { @default_country }
      let(:state)   { country.states.first || create(:state, country: country) }
      let!(:zone)   { create(:zone) }
      let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
      let!(:shipping_method) do
        create(:shipping_method, zones: [zone]).tap do |sm|
          sm.calculator.preferred_amount = 5
          sm.calculator.save
        end
      end
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

      let(:product) { create(:product_in_stock, stores: [store]) }
      let(:variant) { product.default_variant }
      let(:ship_address) { create(:address, country: country, state: state) }
      let!(:order) { create(:order, store: store, state: 'cart', ship_address: ship_address) }

      it 'creates fulfillments and rolls delivery_total into the response' do
        patch :update, params: {
          id: order.prefixed_id,
          items: [{ variant_id: variant.prefixed_id, quantity: 2 }]
        }, as: :json

        expect(response).to have_http_status(:ok)

        order.reload
        expect(order.line_items.find_by(variant: variant).quantity).to eq(2)
        expect(order.shipments).not_to be_empty
        expect(order.shipments.first.shipping_rates).not_to be_empty
        expect(order.shipments.first.selected_shipping_rate).to be_present
        expect(order.shipment_total).to eq(5)

        expect(json_response['delivery_total']).to eq('5.0')
        expect(json_response['total']).to eq(order.total.to_s)
      end

      context 'when the order already has shipments' do
        before do
          # Seed initial shipments via the same Update path so they reflect
          # real Stock::Coordinator output.
          patch :update, params: {
            id: order.prefixed_id,
            items: [{ variant_id: variant.prefixed_id, quantity: 1 }]
          }, as: :json
          order.reload
        end

        it 'rebuilds shipments when items change (old shipment IDs are gone)' do
          old_shipment_ids = order.shipments.map(&:id)
          expect(old_shipment_ids).not_to be_empty

          patch :update, params: {
            id: order.prefixed_id,
            items: [{ variant_id: variant.prefixed_id, quantity: 4 }]
          }, as: :json

          expect(response).to have_http_status(:ok)

          order.reload
          new_shipment_ids = order.shipments.map(&:id)
          expect(new_shipment_ids).not_to be_empty
          expect(new_shipment_ids & old_shipment_ids).to be_empty
          expect(order.shipments.first.inventory_units.sum(:quantity)).to eq(4)
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'deletes a draft order' do
      subject
      expect(response).to have_http_status(:no_content)
    end

    context 'with completed order' do
      let!(:order) { create(:completed_order_with_totals, store: store) }

      it 'returns 403 (cannot delete completed orders)' do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #complete' do
    let!(:order) { create(:order_ready_to_ship, store: store) }

    before { request.headers.merge!(headers) }

    it 'completes the order' do
      patch :complete, params: { id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.completed_at).to be_present
    end

    it 'accepts payment_pending flag without re-processing payments' do
      patch :complete, params: { id: order.prefixed_id, payment_pending: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.completed_at).to be_present
    end

    it 'passes notify_customer flag to the service' do
      service_double = instance_double(Spree::Orders::Complete)
      allow(Spree).to receive(:order_complete_service).and_return(service_double)
      expect(service_double).to receive(:call).with(
        hash_including(order: order, notify_customer: true)
      ).and_return(Spree::ServiceModule::Result.new(true, order, nil))

      patch :complete, params: { id: order.prefixed_id, notify_customer: true }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'omits notify_customer when not given (service defaults to false)' do
      service_double = instance_double(Spree::Orders::Complete)
      allow(Spree).to receive(:order_complete_service).and_return(service_double)
      expect(service_double).to receive(:call) do |args|
        expect(args[:notify_customer]).to be_nil # service default kicks in (false)
        expect(args[:order]).to eq(order)
        Spree::ServiceModule::Result.new(true, order, nil)
      end

      patch :complete, params: { id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    context 'when the order cannot be completed' do
      let!(:order) { create(:order_with_line_items, store: store) }

      it 'returns 422 with order_cannot_complete code and the underlying error message' do
        patch :complete, params: { id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body['error']['code']).to eq('order_cannot_complete')
        expect(body['error']['message']).to include('No payment found')
      end

      it 'surfaces validation errors from the order' do
        service_double = instance_double(Spree::Orders::Complete)
        allow(Spree).to receive(:order_complete_service).and_return(service_double)
        allow(service_double).to receive(:call) do |args|
          args[:order].errors.add(:base, 'Custom failure reason')
          Spree::ServiceModule::Result.new(false, args[:order], 'service error')
        end

        patch :complete, params: { id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body['error']['code']).to eq('order_cannot_complete')
        expect(body['error']['message']).to eq('Custom failure reason')
      end

      it 'falls back to the service error when the order has no errors' do
        service_double = instance_double(Spree::Orders::Complete)
        allow(Spree).to receive(:order_complete_service).and_return(service_double)
        allow(service_double).to receive(:call).and_return(
          Spree::ServiceModule::Result.new(false, order, 'Order is canceled')
        )

        patch :complete, params: { id: order.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body['error']['code']).to eq('order_cannot_complete')
        expect(body['error']['message']).to eq('Order is canceled')
      end
    end
  end

  describe 'PATCH #cancel' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :cancel, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'cancels the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(order.reload.state).to eq('canceled')
    end
  end

  describe 'PATCH #approve' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :approve, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'approves the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['approved_at']).to be_present
    end
  end

  describe 'PATCH #resume' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :resume, params: { id: order.prefixed_id }, as: :json }

    before do
      request.headers.merge!(headers)
      order.canceled_by(admin_user)
    end

    it 'resumes the canceled order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(order.reload.state).to eq('resumed')
    end
  end

  describe 'POST #resend_confirmation' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { post :resend_confirmation, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
    end
  end
end
