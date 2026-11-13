require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:completed_order_with_totals, customer: user, store: store) }
  let!(:other_user_order) { create(:completed_order_with_totals, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns user orders' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['number']).to eq(order.number)
    end

    it 'does not return other users orders' do
      get :index

      numbers = json_response['data'].map { |o| o['number'] }
      expect(numbers).not_to include(other_user_order.number)
    end

    # A history opens on what the customer bought last.
    context 'ordering' do
      let!(:oldest) { create(:completed_order_with_totals, customer: user, store: store) }
      let!(:newest) { create(:completed_order_with_totals, customer: user, store: store) }

      before do
        order.update_columns(completed_at: 2.days.ago)
        oldest.update_columns(completed_at: 10.days.ago)
        newest.update_columns(completed_at: 1.hour.ago)
      end

      it 'lists the newest purchase first' do
        get :index

        expect(json_response['data'].map { |row| row['number'] }).
          to eq([newest.number, order.number, oldest.number])
      end

      # Two checkouts placed in the same second must still page deterministically.
      it 'breaks ties on id, newest first' do
        [order, oldest, newest].each { |o| o.update_columns(completed_at: Time.current) }

        get :index

        ids = json_response['data'].map { |row| row['id'] }
        expect(ids).to eq([newest, oldest, order].sort_by(&:id).reverse.map(&:prefixed_id))
      end

      it 'yields to a sort the caller asked for' do
        get :index, params: { sort: 'completed_at' }

        expect(json_response['data'].map { |row| row['number'] }).
          to eq([oldest.number, order.number, newest.number])
      end
    end

    it 'does not return orders from other stores' do
      other_store = create(:store)
      create(:completed_order_with_totals, customer: user, store: other_store)

      get :index

      numbers = json_response['data'].map { |o| o['number'] }
      expect(numbers).to eq([order.number])
    end

    # Filters are yes/no questions: one that could follow the order into its
    # promotions, or test the email, would answer about data the customer
    # never sees (another shopper's unused coupon codes, staff fields).
    it 'ignores filters that reach beyond the order itself' do
      get :index, params: { q: { promotions_coupon_codes_code_start: 'zzz', email_start: 'zzz', considered_risky_eq: true, search: 'zzz' } }

      expect(json_response['data'].map { |o| o['number'] }).to eq([order.number])
    end

    it 'still filters on the order itself' do
      get :index, params: { q: { number_eq: 'nope' } }

      expect(json_response['data']).to be_empty
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    # The customer made one purchase and paid once, however many sellers it
    # reached, so their history lists the group rather than the orders it
    # divided into.
    context 'when a checkout divided between sellers' do
      let!(:group) { create(:order_group, :with_parcels, store: store, customer: user, sellers_count: 2) }

      before { group.orders.each { |child| child.update_columns(completed_at: Time.current) } }

      it 'lists the purchase once, as the group' do
        get :index

        rows = json_response['data'].reject { |row| row['number'] == order.number }

        expect(rows.size).to eq(1)
        expect(rows.first['id']).to eq(group.prefixed_id)
        expect(rows.first['number']).to eq(group.number)
      end

      it 'never lists a seller order as a purchase of its own' do
        get :index

        numbers = json_response['data'].map { |row| row['number'] }

        expect(numbers).to match_array([order.number, group.number])
        expect(numbers).not_to include(*group.orders.map(&:number))
      end

      it 'nests each seller’s order inside it, for per-seller tracking' do
        get :index

        row = json_response['data'].find { |r| r['number'] == group.number }

        expect(row['orders'].map { |child| child['number'] }).to match_array(group.orders.map(&:number))
        expect(row['orders'].map { |child| child['items'].size }).to all(be_positive)
      end

      it 'counts the purchase once in the pagination meta' do
        get :index

        expect(json_response['meta']['count']).to eq(2)
      end

      it 'leaves an ungrouped order reading as itself' do
        get :index

        row = json_response['data'].find { |r| r['number'] == order.number }

        expect(row['id']).to eq(order.prefixed_id)
        expect(row).not_to have_key('orders')
      end
    end
  end

  describe 'GET #show' do
    let!(:group) { create(:order_group, :with_parcels, store: store, customer: user, sellers_count: 2) }

    it 'resolves the group id the history listed' do
      get :show, params: { id: group.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['number']).to eq(group.number)
      expect(json_response['orders'].size).to eq(2)
    end

    it 'still resolves an ordinary order' do
      get :show, params: { id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['number']).to eq(order.number)
    end

    it 'does not resolve another customer’s group' do
      stranger = create(:order_group, :with_parcels, store: store, sellers_count: 1)

      get :show, params: { id: stranger.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
