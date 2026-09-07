require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockTransfersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { Spree::Store.default }
  let!(:source_location) { create(:stock_location, store: store, name: 'Source') }
  let!(:destination_location) { create(:stock_location, store: store, name: 'Destination') }
  let(:variant) { create(:variant) }

  before do
    request.headers.merge!(headers)
    source_location.restock(variant, 50)
  end

  def create_draft(quantity: 5)
    Spree::StockTransfers::Create.call(
      store: store, source_location: source_location, destination_location: destination_location,
      items: [{ variant: variant, quantity_shipped: quantity }]
    ).value
  end

  describe 'GET #index' do
    let!(:transfer) { create_draft }

    it 'returns stock transfers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |t| t['id'] }).to include(transfer.prefixed_id)
    end

    it 'reports the lifecycle columns the dashboard lists on' do
      get :index, as: :json

      row = json_response['data'].find { |t| t['id'] == transfer.prefixed_id }
      expect(row).to include(
        'status' => 'draft', 'items_count' => 1,
        'quantity_shipped_total' => 5, 'quantity_received_total' => 0, 'editable' => true
      )
    end

    # The table carried no store until 6.0, which left this endpoint reading
    # every tenant's transfers.
    it 'never lists another store’s transfers' do
      other_store = create(:store)
      other_location = create(:stock_location, store: other_store)
      foreign = Spree::StockTransfers::Create.call(
        store: other_store, source_location: other_location,
        destination_location: create(:stock_location, store: other_store),
        items: [{ variant: create(:product, store: other_store).default_variant, quantity_shipped: 1 }]
      ).value

      get :index, as: :json

      expect(json_response['data'].map { |t| t['id'] }).not_to include(foreign.prefixed_id)
    end

    # The dashboard's search box sends this one predicate for both columns, so
    # a whitelist that covers only `number` would silently return every row.
    context 'searching by number or reference' do
      let!(:referenced) do
        Spree::StockTransfers::Create.call(
          store: store, source_location: source_location,
          destination_location: destination_location, reference: 'PO-4471',
          items: [{ variant: variant, quantity_shipped: 1 }]
        ).value
      end

      it 'matches on the reference' do
        get :index, params: { q: { number_or_reference_cont: 'PO-4471' } }, as: :json

        expect(json_response['data'].map { |t| t['id'] }).to eq([referenced.prefixed_id])
      end

      it 'matches on the number' do
        get :index, params: { q: { number_or_reference_cont: transfer.number } }, as: :json

        expect(json_response['data'].map { |t| t['id'] }).to eq([transfer.prefixed_id])
      end
    end
  end

  describe 'POST #create' do
    let(:base_params) do
      {
        source_location_id: source_location.prefixed_id,
        destination_location_id: destination_location.prefixed_id,
        reference: 'Weekly restock',
        items: [{ variant_id: variant.prefixed_id, quantity_shipped: 5 }]
      }
    end

    # The 5.x endpoint moved stock the instant it was called. It now records a
    # plan, which is the whole point of the lifecycle.
    it 'persists a draft without moving any stock' do
      expect { post :create, params: base_params, as: :json }.
        to change(Spree::StockTransfer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include('status' => 'draft', 'reference' => 'Weekly restock')
      expect(source_location.stock_level(variant.id).reload.count_on_hand).to eq(50)
      expect(destination_location.stock_level(variant.id)&.count_on_hand.to_i).to eq(0)
    end

    it 'returns 422 for a line with no quantity' do
      post :create, params: base_params.merge(items: [{ variant_id: variant.prefixed_id, quantity_shipped: 0 }]),
                    as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 when the destination location is unknown' do
      post :create, params: base_params.merge(destination_location_id: 'sloc_unknown'), as: :json

      expect(response).to have_http_status(:not_found)
    end

    # An id resolved through the model constant would accept another store's
    # warehouse; read through current_store it is simply not there.
    it "returns 404 for another store's warehouse" do
      foreign_location = create(:stock_location, store: create(:store))

      post :create, params: base_params.merge(destination_location_id: foreign_location.prefixed_id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another store's variant" do
      foreign_variant = create(:product, store: create(:store)).default_variant

      expect do
        post :create, params: base_params.merge(
          items: [{ variant_id: foreign_variant.prefixed_id, quantity_shipped: 5 }]
        ), as: :json
      end.not_to change(Spree::StockTransfer, :count)

      expect(response).to have_http_status(:not_found)
    end

    [['a bare string', 'five'], ['an object', { variant_id: 'x', quantity_shipped: 1 }]].each do |shape, items|
      it "refuses a payload whose items is #{shape}" do
        expect do
          post :create, params: base_params.merge(items: items), as: :json
        end.not_to change(Spree::StockTransfer, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['details']['base']).to include(
          hash_including('code' => 'invalid_items')
        )
      end
    end
  end

  describe 'PATCH #update' do
    let!(:transfer) { create_draft }

    it 'replaces the lines of a draft' do
      other_variant = create(:variant)

      patch :update, params: {
        id: transfer.prefixed_id, reference: 'Second attempt',
        items: [{ variant_id: other_variant.prefixed_id, quantity_shipped: 2 }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['reference']).to eq('Second attempt')
      line = transfer.reload.items.sole
      expect(line.variant).to eq(other_variant)
      expect(line.quantity_shipped).to eq(2)
    end

    it 'refuses to rewrite a transfer the warehouse is acting on' do
      Spree::StockTransfers::MarkReady.call(stock_transfer: transfer)

      patch :update, params: { id: transfer.prefixed_id, reference: 'too late' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Moving both ends at once would satisfy the same-store validation while
    # leaving the transfer on this store's books.
    it "returns 404 when moving a transfer onto another store's warehouses" do
      other_store = create(:store)

      patch :update, params: {
        id: transfer.prefixed_id,
        source_location_id: create(:stock_location, store: other_store).prefixed_id,
        destination_location_id: create(:stock_location, store: other_store).prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(transfer.reload.source_location).to eq(source_location)
    end
  end

  describe 'the lifecycle actions' do
    let!(:transfer) { create_draft(quantity: 10) }

    it 'marks a draft ready to ship' do
      patch :mark_ready, params: { id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'ready_to_ship', 'editable' => false)
    end

    it 'takes the units off the source shelf when the van leaves' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('in_transit')
      expect(json_response['shipped_at']).to be_present
      expect(source_location.stock_level(variant.id).reload.count_on_hand).to eq(40)
      expect(destination_location.stock_level(variant.id)&.count_on_hand.to_i).to eq(0)
    end

    it 'receives what actually arrived and records the shortfall' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json
      item = transfer.reload.items.sole

      patch :receive, params: {
        id: transfer.prefixed_id,
        items: [{ id: item.prefixed_id, quantity_received: 8, discrepancy_reason: 'damaged_in_transit' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'partially_received',
                                       'quantity_received_total' => 8)
      expect(destination_location.stock_level(variant.id).reload.count_on_hand).to eq(8)
      expect(item.reload.discrepancy_reason).to eq('damaged_in_transit')
    end

    it 'receives everything when the payload names no lines' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json

      patch :receive, params: { id: transfer.prefixed_id }, as: :json

      expect(json_response['status']).to eq('received')
      expect(destination_location.stock_level(variant.id).reload.count_on_hand).to eq(10)
    end

    # An `items` the caller got wrong must not fall through to receive-all.
    it 'refuses a receive whose items is an object rather than a list' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json

      patch :receive, params: {
        id: transfer.prefixed_id, items: { id: 'x', quantity_received: 1 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['base']).to include(
        hash_including('code' => 'invalid_items')
      )
      expect(transfer.reload.status).to eq('in_transit')
      expect(transfer.quantity_received_total).to eq(0)
    end

    it "returns 404 for a line belonging to another transfer" do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json
      foreign_item = create_draft.items.sole

      patch :receive, params: {
        id: transfer.prefixed_id, items: [{ id: foreign_item.prefixed_id, quantity_received: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses to cancel an in-transit transfer without a decision' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json

      patch :cancel, params: { id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(transfer.reload).to be_in_transit
    end

    it 'puts the units back when the merchant says they came home' do
      patch :mark_in_transit, params: { id: transfer.prefixed_id }, as: :json

      patch :cancel, params: { id: transfer.prefixed_id, on_in_transit: 'restock' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('canceled')
      expect(source_location.stock_level(variant.id).reload.count_on_hand).to eq(50)
    end
  end

  describe 'DELETE #destroy' do
    let!(:transfer) { create_draft }

    it 'throws a draft away' do
      expect { delete :destroy, params: { id: transfer.prefixed_id }, as: :json }.
        to change(Spree::StockTransfer, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    # Really gone, not stamped. The soft-delete column exists for the upgrade
    # task's converted receives, whose numbers have to stay findable; a draft
    # nobody sent has nothing to preserve, and `destroy` hard-deletes its lines
    # regardless, which would leave a row that could never be restored intact.
    it 'leaves no soft-deleted row or orphaned lines behind' do
      item_id = transfer.items.sole.id

      delete :destroy, params: { id: transfer.prefixed_id }, as: :json

      expect(Spree::StockTransfer.only_deleted.where(id: transfer.id)).to be_empty
      expect(Spree::StockTransferItem.where(id: item_id)).to be_empty
    end

    # Past draft the transfer describes a box that physically exists.
    it 'refuses to delete a transfer that has shipped' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      delete :destroy, params: { id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('invalid_status')
    end
  end
end
