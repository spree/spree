require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PurchaseOrders::StockReceiptsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { Spree::Store.default }
  let!(:supplier) { create(:supplier, store: store) }
  let!(:destination_location) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  let!(:purchase_order) do
    Spree::PurchaseOrders::Create.call(
      store: store, supplier: supplier, destination_location: destination_location,
      items: [{ variant: variant, quantity_ordered: 100, unit_cost: 12.5 }]
    ).value
  end
  let(:item) { purchase_order.items.sole }

  before { request.headers.merge!(headers) }

  def on_hand
    destination_location.stock_level(variant.id)&.count_on_hand.to_i
  end

  def place
    Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)
  end

  describe 'POST #create' do
    it 'books in what the supplier delivered, as a receipt' do
      place

      post :create, params: {
        purchase_order_id: purchase_order.prefixed_id, reference: 'DN-4471',
        items: [{ id: item.prefixed_id, quantity_accepted: 58, quantity_rejected: 2, rejection_reason: 'damaged' }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response).to include('reference' => 'DN-4471', 'receivable_type' => 'purchase_order',
                                       'receivable_id' => purchase_order.prefixed_id,
                                       'quantity_accepted_total' => 58, 'quantity_rejected_total' => 2)
      expect(json_response['number']).to start_with('SR')
      expect(purchase_order.reload).to be_partially_received
      expect(on_hand).to eq(58)
    end

    it 'records what the units cost on the movement that landed them, and which delivery' do
      place

      post :create, params: { purchase_order_id: purchase_order.prefixed_id }, as: :json

      movement = purchase_order.reload.stock_movements.sole
      expect(movement.unit_cost).to eq(12.5)
      expect(movement.stock_receipt.prefixed_id).to eq(json_response['id'])
      expect(purchase_order).to be_received
    end

    it 'refuses a delivery against an order that has not been placed' do
      post :create, params: { purchase_order_id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(on_hand).to eq(0)
    end

    # An `items` the caller got wrong must not fall through to receive-all.
    it 'refuses a payload whose items is an object rather than a list' do
      place

      post :create, params: {
        purchase_order_id: purchase_order.prefixed_id, items: { id: 'x', quantity_accepted: 1 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['base']).to include(hash_including('code' => 'invalid_items'))
      expect(on_hand).to eq(0)
    end

    it 'returns 404 for a line belonging to another order' do
      place
      foreign_item = create(:purchase_order, store: store).items.sole

      post :create, params: {
        purchase_order_id: purchase_order.prefixed_id, items: [{ id: foreign_item.prefixed_id, quantity_accepted: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another store's order" do
      other_store = create(:store)
      foreign = Spree::PurchaseOrders::Create.call(
        store: other_store, supplier: create(:supplier, store: other_store),
        destination_location: create(:stock_location, store: other_store),
        items: [{ variant: create(:product, store: other_store).default_variant, quantity_ordered: 1, unit_cost: 1 }]
      ).value

      post :create, params: { purchase_order_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    it 'lists the deliveries booked against the order, with their lines on request' do
      place
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload, reference: 'DN-1',
                                          items: [{ item: item, quantity_accepted: 60 }])
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload, reference: 'DN-2',
                                          items: [{ item: item.reload, quantity_accepted: 40 }])

      get :index, params: { purchase_order_id: purchase_order.prefixed_id, expand: 'items' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |receipt| receipt['reference'] }).to contain_exactly('DN-1', 'DN-2')
      line = json_response['data'].first['items'].sole
      expect(line).to include('line_type' => 'purchase_order_item', 'line_id' => item.prefixed_id,
                              'variant_sku' => variant.sku)
    end
  end
end
