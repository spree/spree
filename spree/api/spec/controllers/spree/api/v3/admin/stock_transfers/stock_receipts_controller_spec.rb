require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockTransfers::StockReceiptsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { Spree::Store.default }
  let!(:source_location) { create(:stock_location, store: store) }
  let!(:destination_location) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  let!(:transfer) do
    Spree::StockTransfers::Create.call(
      store: store, source_location: source_location, destination_location: destination_location,
      items: [{ variant: variant, quantity_shipped: 10 }]
    ).value
  end
  let(:item) { transfer.items.sole }

  before do
    request.headers.merge!(headers)
    source_location.restock(variant, 50)
  end

  def destination_on_hand
    destination_location.stock_level(variant.id)&.count_on_hand.to_i
  end

  def ship
    Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)
  end

  describe 'POST #create' do
    it 'counts in what arrived and records what was refused' do
      ship

      post :create, params: {
        stock_transfer_id: transfer.prefixed_id,
        items: [{ id: item.prefixed_id, quantity_accepted: 8, quantity_rejected: 2, rejection_reason: 'damaged' }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response).to include('receivable_type' => 'stock_transfer', 'receivable_id' => transfer.prefixed_id,
                                       'quantity_accepted_total' => 8, 'quantity_rejected_total' => 2)
      expect(transfer.reload).to be_received
      expect(destination_on_hand).to eq(8)
    end

    it 'counts in everything when the payload names no lines' do
      ship

      post :create, params: { stock_transfer_id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(transfer.reload).to be_received
      expect(destination_on_hand).to eq(10)
    end

    it 'leaves the transfer open while units are still on the road' do
      ship

      post :create, params: {
        stock_transfer_id: transfer.prefixed_id, items: [{ id: item.prefixed_id, quantity_accepted: 8 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(transfer.reload).to be_partially_received
    end

    it 'refuses a delivery against a transfer that has not shipped' do
      post :create, params: { stock_transfer_id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(destination_on_hand).to eq(0)
    end

    # An `items` the caller got wrong must not fall through to receive-all.
    it 'refuses a payload whose items is an object rather than a list' do
      ship

      post :create, params: {
        stock_transfer_id: transfer.prefixed_id, items: { id: 'x', quantity_accepted: 1 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['base']).to include(hash_including('code' => 'invalid_items'))
      expect(transfer.reload).to be_in_transit
    end

    it 'returns 404 for a line belonging to another transfer' do
      ship
      foreign_item = create(:stock_transfer, store: store).items.sole

      post :create, params: {
        stock_transfer_id: transfer.prefixed_id, items: [{ id: foreign_item.prefixed_id, quantity_accepted: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    it 'lists the deliveries counted in against the transfer' do
      ship
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload, reference: 'Van 3',
                                          items: [{ item: item, quantity_accepted: 8 }])

      get :index, params: { stock_transfer_id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].sole).to include('reference' => 'Van 3', 'quantity_accepted_total' => 8)
    end
  end
end
