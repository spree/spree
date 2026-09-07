require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockMovementsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }
  let!(:variant) { create(:variant) }
  let!(:movement) { stock_location.adjust(variant, 3, reason: 'Cycle count') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the stock ledger' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |m| m['id'] }).to include(movement.prefixed_id)
    end

    it 'exposes the kind, the reason and the cause keys' do
      get :index, as: :json

      row = json_response['data'].find { |m| m['id'] == movement.prefixed_id }
      expect(row['kind']).to eq('adjusted')
      expect(row['reason']).to eq('Cycle count')
      expect(row).to have_key('fulfillment_id')
      expect(row).to have_key('order_id')
      expect(row).not_to have_key('originator_type')
      expect(row).not_to have_key('originator_id')
    end

    it 'carries the fulfillment and its order on an allocation' do
      order = create(:order_ready_to_ship, store: store, line_items_count: 1)
      fulfillment = order.fulfillments.first
      allocated_variant = fulfillment.fulfillment_items.first.variant
      allocation = fulfillment.stock_location.allocate(allocated_variant, 1, fulfillment)

      get :index, params: { q: { kind_eq: 'allocated' } }, as: :json

      row = json_response['data'].find { |m| m['id'] == allocation.prefixed_id }
      expect(row['fulfillment_id']).to eq(fulfillment.prefixed_id)
      expect(row['order_id']).to eq(order.prefixed_id)
    end

    it 'filters by kind' do
      get :index, params: { q: { kind_eq: 'shipped' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_empty
    end

    # The two filters the dashboard's history panels read through: a movement
    # carries no variant or location of its own, so both reach through the
    # stock level (docs/plans/6.0-inventory-operations.md).
    it 'filters by variant, for the history panel on a product' do
      other_movement = stock_location.adjust(create(:variant), 2, reason: 'Cycle count')

      get :index, params: { q: { stock_level_variant_id_in: [variant.prefixed_id] } }, as: :json

      ids = json_response['data'].map { |m| m['id'] }
      expect(ids).to include(movement.prefixed_id)
      expect(ids).not_to include(other_movement.prefixed_id)
    end

    it 'filters by warehouse, for the activity panel on a stock location' do
      other_location = create(:stock_location, store: store)
      other_movement = other_location.adjust(variant, 2, reason: 'Cycle count')

      get :index, params: { q: { stock_level_stock_location_id_eq: stock_location.prefixed_id } }, as: :json

      ids = json_response['data'].map { |m| m['id'] }
      expect(ids).to include(movement.prefixed_id)
      expect(ids).not_to include(other_movement.prefixed_id)
    end

    it 'carries the purchase order and the unit cost on a received row' do
      purchase_order = create(:purchase_order, :ordered, store: store, quantity: 4, unit_cost: 9.5)
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order)

      get :index, params: { q: { kind_eq: 'received' } }, as: :json

      row = json_response['data'].find { |m| m['purchase_order_id'] == purchase_order.prefixed_id }
      expect(row['unit_cost']).to eq('9.5')
      expect(row['display_unit_cost']).to eq('$9.50')
    end

    # spree_stock_movements carries no store of its own, so tenancy is the walk
    # through stock level → variant → product → store.
    it 'excludes movements for another store\'s products' do
      other_store = create(:store)
      other_variant = create(:product, store: other_store).default_variant
      other_movement = stock_location.adjust(other_variant, 1, reason: 'Cycle count')

      get :index, as: :json

      expect(json_response['data'].map { |m| m['id'] }).not_to include(other_movement.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the movement' do
      get :show, params: { id: movement.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(movement.prefixed_id)
    end

    it 'returns 404 for a movement belonging to another store' do
      other_store = create(:store)
      other_variant = create(:product, store: other_store).default_variant
      other_movement = stock_location.adjust(other_variant, 1, reason: 'Cycle count')

      get :show, params: { id: other_movement.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'writes' do
    it 'has no create, update or destroy route' do
      expect { post :create, as: :json }.to raise_error(ActionController::UrlGenerationError)
      expect { delete :destroy, params: { id: movement.prefixed_id }, as: :json }.
        to raise_error(ActionController::UrlGenerationError)
    end
  end
end
