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

      it 'filters by completion' do
        get :index, params: { q: { completed_at_not_null: 1 } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['id']).to eq(completed_order.prefixed_id)
      end

      context 'filtering by channel_id' do
        let(:pos_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }
        let!(:pos_order) { create(:order, store: store, channel: pos_channel) }
        let!(:default_channel_order) { create(:order, store: store, channel: store.default_channel) }

        it 'returns only orders on the requested channel via channel_id_eq' do
          get :index, params: { q: { channel_id_eq: pos_channel.id } }, as: :json

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |o| o['id'] }
          expect(ids).to include(pos_order.prefixed_id)
          expect(ids).not_to include(default_channel_order.prefixed_id)
        end

        it 'returns orders across multiple channels via channel_id_in' do
          get :index, params: { q: { channel_id_in: [pos_channel.id, store.default_channel.id] } }, as: :json

          expect(response).to have_http_status(:ok)
          ids = json_response['data'].map { |o| o['id'] }
          expect(ids).to include(pos_order.prefixed_id, default_channel_order.prefixed_id)
        end
      end
    end

    context 'with q[search] (full-text search)' do
      # Factories auto-attach a customer and a `before_create :link_by_email`
      # callback resets `email` from `customer.email`. Pass `customer: nil` so our
      # explicit email sticks for the email-match assertion.
      let!(:matching_order) do
        create(:order, store: store, state: 'cart', customer: nil, email: 'jane.doe@example.com')
      end
      let!(:non_matching_order) do
        create(:order, store: store, state: 'cart', customer: nil, email: 'someone-else@example.com')
      end

      it 'matches by order number substring' do
        substring = matching_order.number[1..6] # 'R' + 6 chars is unique enough to not collide
        get :index, params: { q: { search: substring } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |o| o['id'] }
        expect(ids).to include(matching_order.prefixed_id)
      end

      it 'matches by exact email' do
        get :index, params: { q: { search: 'jane.doe@example.com' } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |o| o['id'] }
        expect(ids).to include(matching_order.prefixed_id)
        expect(ids).not_to include(non_matching_order.prefixed_id)
      end

      it 'returns no results when nothing matches' do
        get :index, params: { q: { search: 'xqzwkj-no-such-order' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_empty
      end
    end

    # What an operator needs from the list once a checkout can divide across
    # sellers: which seller a row belongs to, which purchase it was part of,
    # and the ability to narrow to either. The dashboard's columns send
    # prefixed ids, so that is what these filter on.
    context 'on a marketplace' do
      let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
      let(:other_seller) { create(:seller, :approved, store: store, name: 'Quill Books') }
      let(:group) { create(:order_group, store: store) }

      let!(:seller_order) do
        create(:order, store: store, order_group: group, seller: seller, status: 'placed', completed_at: Time.current)
      end
      let!(:first_party_order) do
        create(:order, store: store, order_group: group, status: 'placed', completed_at: Time.current)
      end
      let!(:ungrouped_order) do
        create(:order, store: store, seller: other_seller, status: 'placed', completed_at: Time.current)
      end

      def row_for(record)
        json_response['data'].find { |row| row['number'] == record.number }
      end

      def numbers
        json_response['data'].map { |row| row['number'] }
      end

      it 'names the seller on each row' do
        get :index, as: :json

        expect(row_for(seller_order)['seller_id']).to eq(seller.prefixed_id)
      end

      it 'carries the whole profile when asked to expand it' do
        get :index, params: { expand: 'seller' }, as: :json

        expect(row_for(seller_order)['seller']['name']).to eq('Sparks Audio')
      end

      it 'leaves the operator’s own order without a seller' do
        get :index, as: :json

        expect(row_for(first_party_order)['seller_id']).to be_nil
        expect(row_for(first_party_order)['seller']).to be_nil
      end

      it 'names the purchase a row was part of' do
        get :index, as: :json

        expect(row_for(seller_order)['order_group_id']).to eq(group.prefixed_id)
      end

      it 'leaves an ungrouped order without a purchase' do
        get :index, as: :json

        expect(row_for(ungrouped_order)['order_group_id']).to be_nil
      end

      it 'narrows to one seller' do
        get :index, params: { q: { seller_id_eq: seller.prefixed_id } }, as: :json

        expect(numbers).to contain_exactly(seller_order.number)
      end

      it 'narrows to several sellers at once, as the picker sends them' do
        get :index, params: { q: { seller_id_in: [seller.prefixed_id, other_seller.prefixed_id] } }, as: :json

        expect(numbers).to contain_exactly(seller_order.number, ungrouped_order.number)
      end

      it 'narrows to the orders of one purchase' do
        get :index, params: { q: { order_group_id_eq: group.prefixed_id } }, as: :json

        expect(numbers).to contain_exactly(seller_order.number, first_party_order.number)
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
    it 'expands the originating cart on a placed order' do
      cart = create(:cart_with_line_items, store: store)
      cart.update_columns(completed_at: Time.current)
      placed = create(:completed_order_with_totals, store: store, cart_id: cart.id)

      get :show, params: { id: placed.prefixed_id, expand: 'cart' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['cart_id']).to eq(cart.prefixed_id)
      expect(json_response['cart']['id']).to eq(cart.prefixed_id)
      expect(json_response['cart']['completed_at']).to be_present
    end

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
        expect(created_order.customer).to eq(customer)
      end

      it 'refuses to attach a customer the principal is not allowed to see' do
        restricted = Spree::Ability.new(admin_user)
        restricted.cannot :show, Spree.customer_class, id: customer.id
        allow_any_instance_of(described_class).to receive(:current_ability).and_return(restricted)

        expect { subject }.not_to change(Spree::Order, :count)
        expect(response).to have_http_status(:not_found)
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
      let!(:shipping_method) do
        create(:shipping_method).tap do |sm|
          sm.calculator.preferred_amount = 5
          sm.calculator.save
        end
      end
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

      let(:product) { create(:product_in_stock) }
      let(:variant) { product.default_variant }

      let(:create_params) do
        {
          email: 'test@example.com',
          items: [{ variant_id: variant.prefixed_id, quantity: 2 }],
          shipping_address: {
            firstname: 'Jane', lastname: 'Doe',
            address1: '350 Fifth Avenue', city: 'New York',
            zipcode: '10118', phone: '555-555-0199',
            country_code: country.iso, state_code: state.abbr
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

    context 'with preferred_stock_location_id (routes to that location)' do
      let(:country) { @default_country }
      let(:state)   { country.states.first || create(:state, country: country) }
      let!(:zone)   { create(:zone) }
      let!(:shipping_method) do
        create(:shipping_method).tap do |sm|
          sm.calculator.preferred_amount = 5
          sm.calculator.save
        end
      end

      let!(:default_location)   { create(:stock_location, name: 'NYC default', default: true,  country: country, state: state) }
      let!(:preferred_location) { create(:stock_location, name: 'LA preferred', default: false, country: country, state: state) }

      let(:variant) { create(:variant) }

      before do
        default_location.stock_level_or_create(variant).update!(count_on_hand: 10)
        preferred_location.stock_level_or_create(variant).update!(count_on_hand: 10)
      end

      let(:create_params) do
        {
          email: 'test@example.com',
          preferred_stock_location_id: preferred_location.prefixed_id,
          items: [{ variant_id: variant.prefixed_id, quantity: 2 }],
          shipping_address: {
            firstname: 'Jane', lastname: 'Doe',
            address1: '350 Fifth Avenue', city: 'New York',
            zipcode: '10118', phone: '555-555-0199',
            country_code: country.iso, state_code: state.abbr
          }
        }
      end

      it 'persists the preferred_stock_location association' do
        subject

        expect(response).to have_http_status(:created)
        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.preferred_stock_location).to eq(preferred_location)
      end

      it 'exposes preferred_stock_location_id in the JSON response' do
        subject
        expect(json_response['preferred_stock_location_id']).to eq(preferred_location.prefixed_id)
      end

      it 'routes the resulting fulfillment to the preferred location, not the default' do
        subject

        created = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created.shipments).not_to be_empty
        expect(created.shipments.map(&:stock_location)).to all(eq(preferred_location))
        expect(created.shipments.map(&:stock_location)).not_to include(default_location)
      end

      context 'when the preferred location does not stock the variant' do
        before do
          preferred_location.stock_levels.where(variant_id: variant.id).destroy_all
        end

        it 'falls back to the default location instead of erroring' do
          subject

          expect(response).to have_http_status(:created)
          created = Spree::Order.find_by_prefix_id(json_response['id'])
          expect(created.preferred_stock_location).to eq(preferred_location)
          expect(created.shipments.map(&:stock_location)).to all(eq(default_location))
        end
      end

      context 'with an unknown preferred_stock_location_id' do
        let(:create_params) do
          {
            email: 'test@example.com',
            preferred_stock_location_id: 'sloc_doesnotexist'
          }
        end

        it 'returns a not-found error rather than silently dropping the preference' do
          expect { subject }.not_to change(Spree::Order, :count)
          expect(response).to have_http_status(:not_found)
        end
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

    # The admin order edit screen submits every row it shows in one request:
    # changed quantities as their new value, struck-out rows as zero.
    context 'with a whole edited order in one request' do
      let(:order) { create(:order_with_line_items, store: store, line_items_count: 2) }
      let(:kept) { order.line_items.first }
      let(:removed) { order.line_items.last }

      it 'applies the quantity changes and the removals together' do
        patch :update, params: {
          id: order.prefixed_id,
          items: [
            { variant_id: kept.variant.prefixed_id, quantity: 3 },
            { variant_id: removed.variant.prefixed_id, quantity: 0 }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.line_items).to contain_exactly(kept)
        expect(kept.reload.quantity).to eq(3)
      end
    end

    # Staff assigning the business an order is for — the only route to an
    # exemption for a buyer who acts for several companies, until session-level
    # selection is settled with channels and catalogs.
    context 'assigning the business the order is for' do
      let(:company) { create(:company, store: store) }
      let(:location) { create(:company_location, company: company) }

      it 'sets the branch and reports the company' do
        patch :update, params: { id: order.prefixed_id, company_location_id: location.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['company_location_id']).to eq(location.prefixed_id)
        expect(json_response['company_id']).to eq(company.prefixed_id)
        expect(order.reload.company).to eq(company)
      end

      it 'refuses a branch belonging to another store' do
        elsewhere = create(:company_location, company: create(:company, store: create(:store)))

        patch :update, params: { id: order.prefixed_id, company_location_id: elsewhere.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(order.reload.company_location_id).to be_nil
      end

      it 'clears the branch when passed nothing' do
        order.update!(company_location: location)

        patch :update, params: { id: order.prefixed_id, company_location_id: nil }, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.company_location_id).to be_nil
      end
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
      let!(:order) { create(:order, store: store, state: 'cart', customer: original_customer) }

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
      let!(:shipping_method) do
        create(:shipping_method).tap do |sm|
          sm.calculator.preferred_amount = 5
          sm.calculator.save
        end
      end
      let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }

      let(:product) { create(:product_in_stock) }
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
        expect(order.fulfillments.first.shipping_rates).not_to be_empty
        expect(order.fulfillments.first.selected_shipping_rate).to be_present
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
          expect(order.fulfillments.first.inventory_units.sum(:quantity)).to eq(4)
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

      # Record-state eligibility lives on the model (Axis A/B split), so the
      # caller is authorized but the resource's state blocks the operation:
      # 422, matching every other `can_be_deleted?` guard.
      it 'returns 422 (completed orders cannot be deleted)' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(Spree::Order.find_by(id: order.id)).to be_present
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
    let(:params) { { id: order.prefixed_id } }

    subject { patch :cancel, params: params, as: :json }

    before { request.headers.merge!(headers) }

    it 'cancels the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(order.reload).to be_canceled
    end

    context 'when notify_customer is not passed' do
      it 'does not flag the cancellation for customer notification' do
        subject

        expect(order.cancellations.last.notify_customer).to be false
      end
    end

    context 'when notify_customer is truthy' do
      let(:params) { { id: order.prefixed_id, notify_customer: 'true' } }

      it 'flags the cancellation for customer notification' do
        subject

        expect(order.cancellations.last.notify_customer).to be true
      end
    end

    context 'when notify_customer is falsy' do
      let(:params) { { id: order.prefixed_id, notify_customer: 'false' } }

      it 'does not flag the cancellation for customer notification' do
        subject

        expect(order.cancellations.last.notify_customer).to be false
      end
    end

    context 'when the order cannot be canceled' do
      before { allow_any_instance_of(Spree::Order).to receive(:allow_cancel?).and_return(false) }

      it 'returns 422 and leaves the order untouched' do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(order.reload).not_to be_canceled
      end
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
      Spree.order_cancel_workflow.call(order: order, canceler: admin_user)
    end

    it 'resumes the canceled order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(order.reload).not_to be_canceled
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
