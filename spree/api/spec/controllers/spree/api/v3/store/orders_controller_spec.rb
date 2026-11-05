require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    let(:order) { create(:completed_order_with_totals, customer: user, store: store) }

    context 'authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns the order' do
        get :show, params: { id: order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(order.number)
      end

      it 'returns order with expected attributes' do
        get :show, params: { id: order.to_param }

        expect(json_response['id']).to eq(order.prefixed_id)
        expect(json_response['number']).to eq(order.number)
      end
    end

    context 'with the cart handle after completion' do
      let(:cart) { create(:cart_with_line_items, store: store) }
      let!(:completed_order) do
        create(:completed_order_with_totals, customer: nil, store: store, cart_id: cart.id, token: cart.token)
      end

      before { cart.update_columns(completed_at: Time.current) }

      # The storefront keeps the cart id through checkout; after completion
      # the same handle + cart token must resolve the resulting order.
      it 'resolves the order created from that cart' do
        request.headers['x-spree-token'] = cart.token

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(completed_order.prefixed_id)
        expect(json_response['number']).to eq(completed_order.number)
      end

      it 'returns not found without the matching token' do
        request.headers['x-spree-token'] = 'wrong-token'

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    # A basket that reached several sellers divided into one order per seller
    # and the cart handle moved up to the group holding them, so no order
    # carries it any more. The confirmation page asks with the handle it has
    # and has to be given the whole purchase.
    context 'with the cart handle after a checkout that split across sellers' do
      let(:cart) { create(:cart_with_line_items, store: store) }
      let!(:group) do
        create(:order_group, :with_parcels, store: store, customer: nil, cart: cart, token: cart.token)
      end

      before do
        cart.update_columns(completed_at: Time.current)
        request.headers['x-spree-token'] = cart.token
      end

      it 'resolves the cart handle to the group' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(group.prefixed_id)
        expect(json_response['number']).to eq(group.number)
      end

      it 'answers with every seller’s items rather than one order’s' do
        get :show, params: { id: cart.prefixed_id }

        expect(json_response['orders'].size).to eq(2)
        expect(json_response['orders'].sum { |order| order['items'].size }).to eq(2)
      end

      it 'sums the delivery the children were quoted' do
        get :show, params: { id: cart.prefixed_id }

        expect(BigDecimal(json_response['delivery_total'])).
          to eq(group.orders.sum(&:delivery_total))
      end

      it 'carries the payment the group was charged, which no child holds' do
        payment = create(:payment, order: nil, order_group: group, amount: group.total)

        get :show, params: { id: cart.prefixed_id }

        expect(json_response['payments'].map { |row| row['id'] }).to eq([payment.prefixed_id])
        expect(json_response['orders'].flat_map { |order| order['payments'] }).to be_empty
      end

      # Completion hands the client a group id; re-reading with it must work
      # the same way +carts#complete+ already accepts it on retry.
      it 'resolves the group’s own id too' do
        get :show, params: { id: group.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(group.prefixed_id)
      end

      it 'returns not found without the matching token' do
        request.headers['x-spree-token'] = 'wrong-token'

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end

      it 'runs no more queries for a checkout that reached more sellers' do
        larger_cart = create(:cart_with_line_items, store: store)
        larger_cart.update_columns(completed_at: Time.current)
        create(:order_group, :with_parcels, store: store, customer: nil, cart: larger_cart,
                                            token: larger_cart.token, sellers_count: 3)

        count_queries = lambda do |handle, token|
          request.headers['x-spree-token'] = token
          queries = 0
          counter = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }
          ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get :show, params: { id: handle } }
          queries
        end

        expect(count_queries.call(larger_cart.prefixed_id, larger_cart.token)).
          to eq(count_queries.call(cart.prefixed_id, cart.token))
      end
    end

    context 'with spree token' do
      let(:guest_order) { create(:completed_order_with_totals, customer: nil, store: store) }

      it 'returns the order for guest with valid token' do
        request.headers['x-spree-token'] = guest_order.token
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(guest_order.number)
      end

      it 'returns not found with invalid token' do
        request.headers['x-spree-token'] = 'invalid'
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found without token' do
        get :show, params: { id: guest_order.to_param }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'returns not found for invalid order id' do
        get :show, params: { id: 'or_invalid' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for other users order' do
        other_order = create(:completed_order_with_totals, store: store)
        get :show, params: { id: other_order.to_param }

        expect(response).to have_http_status(:not_found)
      end

      # A checkout's own draft belongs to its cart, which the buyer reads.
      it 'returns not found for the transient draft of a checkout' do
        cart = create(:cart_with_line_items, customer: user, store: store)
        incomplete_order = create(:order_with_line_items, payment_requested_at: Time.current, customer: user, store: store, cart_id: cart.id)
        get :show, params: { id: incomplete_order.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for a canceled draft' do
        canceled_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: user, store: store)
        canceled_draft.update_columns(status: 'canceled')
        get :show, params: { id: canceled_draft.to_param }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a draft order raised for the buyer' do
      let!(:payment_method) { create(:bogus_payment_method) }
      let(:draft) { create(:order_with_line_items, payment_requested_at: Time.current, customer: user, store: store) }

      before { request.headers['Authorization'] = "Bearer #{jwt_token}" }

      it 'returns the draft with the methods it can be paid with' do
        get :show, params: { id: draft.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(draft.prefixed_id)
        expect(json_response['completed_at']).to be_nil
        expect(json_response['payment_methods'].map { |method| method['id'] }).to include(payment_method.prefixed_id)
      end

      it 'returns not found until the merchant requests payment' do
        draft.update_columns(payment_requested_at: nil)
        get :show, params: { id: draft.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'leaves the payment methods off a placed order' do
        get :show, params: { id: order.to_param }

        expect(json_response).not_to have_key('payment_methods')
      end

      it 'returns not found for another customer’s draft' do
        other_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: create(:user), store: store)
        get :show, params: { id: other_draft.to_param }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns a guest draft to the bearer of its token' do
        guest_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: nil, store: store)
        request.headers['Authorization'] = nil
        request.headers['x-spree-token'] = guest_draft.token

        get :show, params: { id: guest_draft.to_param }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(guest_draft.prefixed_id)
      end
    end
  end

  describe 'POST #complete' do
    let(:draft) { create(:order_with_line_items, payment_requested_at: Time.current, customer: user, store: store) }
    let(:published) { [] }

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      allow(Spree::Events).to receive(:publish) { |name, *| published << name }
    end

    it 'places the draft, processing its payment', :events do
      payment = create(:payment, order: draft, amount: draft.total).tap(&:create_payment_profile)

      post :complete, params: { id: draft.prefixed_id }

      expect(published).to include('order.placed')
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(draft.prefixed_id)
      expect(json_response['completed_at']).to be_present
      expect(draft.reload).to be_placed
      expect(payment.reload).to be_completed
    end

    it 'places the draft once a payment session settled its payment' do
      session = create(:bogus_payment_session, order: draft, payment_method: create(:bogus_payment_method),
                                               amount: draft.total)
      session.settle_payment!(captured: true)

      post :complete, params: { id: draft.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(draft.reload).to be_placed
      expect(draft.payments.completed.sum(:amount)).to eq(draft.total)
    end

    it 'places a guest draft for the bearer of its token' do
      guest_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: nil, email: 'buyer@example.com', store: store)
      create(:payment, order: guest_draft, amount: guest_draft.total).tap(&:create_payment_profile)
      request.headers['Authorization'] = nil
      request.headers['x-spree-token'] = guest_draft.token

      post :complete, params: { id: guest_draft.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(guest_draft.reload).to be_placed
    end

    it 'refuses without a payment covering the total, leaving the draft' do
      post :complete, params: { id: draft.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('order_cannot_complete')
      expect(draft.reload).to be_draft
    end

    # A double-clicked Pay, or a webhook that placed it first.
    it 'answers with an already placed order without placing it again', :events do
      draft.update_columns(status: 'placed', completed_at: Time.current)

      post :complete, params: { id: draft.prefixed_id }

      expect(published).not_to include('order.placed')
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(draft.prefixed_id)
    end

    it 'returns not found for another customer’s draft' do
      other_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: create(:user), store: store)

      post :complete, params: { id: other_draft.prefixed_id }

      expect(response).to have_http_status(:not_found)
      expect(other_draft.reload).to be_draft
    end

    it 'returns not found for a draft in another store' do
      other_draft = create(:order_with_line_items, payment_requested_at: Time.current, customer: user, store: create(:store))

      post :complete, params: { id: other_draft.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a draft without a payment request' do
      draft.update_columns(payment_requested_at: nil)
      create(:payment, order: draft, amount: draft.total).tap(&:create_payment_profile)

      post :complete, params: { id: draft.prefixed_id }

      expect(response).to have_http_status(:not_found)
      expect(draft.reload).to be_draft
    end

    it 'returns not found for a canceled order' do
      draft.update_columns(status: 'canceled')

      post :complete, params: { id: draft.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
