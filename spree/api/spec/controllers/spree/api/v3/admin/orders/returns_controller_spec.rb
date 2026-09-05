require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ReturnsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:fulfillment_item) { order.fulfillment_items.first }

  before { request.headers.merge!(headers) }

  def create_return(status: 'requested')
    create(:return, store: store, order: order, status: status)
  end

  describe 'POST #create' do
    it 'opens a return for the requested items' do
      post :create, params: {
        order_id: order.prefixed_id,
        memo: 'Too small',
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('requested')
      expect(json_response['number']).to start_with('RET')
      expect(json_response['memo']).to eq('Too small')
    end

    it 'rejects returning more than was fulfilled' do
      post :create, params: {
        order_id: order.prefixed_id,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 99 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET #index' do
    it 'lists returns on the order' do
      create_return

      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns the record with its line items' do
      return_record = create_return

      get :show, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(return_record.prefixed_id)
      expect(json_response['refund_total']).to be_present
    end
  end

  describe 'PATCH #update' do
    it 'edits the memo without touching status' do
      return_record = create_return

      patch :update, params: { order_id: order.prefixed_id, id: return_record.prefixed_id, memo: 'Updated' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['memo']).to eq('Updated')
      expect(json_response['status']).to eq('requested')
    end
  end

  describe 'PATCH #approve' do
    it 'approves a requested return' do
      return_record = create_return

      patch :approve, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('approved')
      expect(json_response['approved_at']).to be_present
    end

    it 'refuses a return that is not requested' do
      return_record = create_return(status: 'approved')

      patch :approve, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #receive' do
    let(:return_record) { create(:approved_return, store: store, order: order) }

    it 'receives everything as requested by default' do
      patch :receive, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('received')
    end

    # Omitting `items` means "everything as requested"; naming an empty list
    # means the caller named no units, which must not fall through to that.
    it 'refuses an explicitly empty item list rather than receiving everything' do
      line = return_record.return_line_items.first

      patch :receive, params: {
        order_id: order.prefixed_id, id: return_record.prefixed_id, items: []
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(line.reload.received_quantity).to eq(0)
    end

    it 'records a partial, non-resellable receipt' do
      line = return_record.return_line_items.first

      patch :receive, params: {
        order_id: order.prefixed_id,
        id: return_record.prefixed_id,
        items: [{ return_line_item_id: line.prefixed_id, quantity: 1, resellable: false }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(line.reload.received_quantity).to eq(1)
      expect(line.resellable).to be(false)
    end
  end

  describe 'PATCH #refund' do
    let(:return_record) { create(:received_return, store: store, order: order) }

    it 'refunds to store credit' do
      patch :refund, params: {
        order_id: order.prefixed_id,
        id: return_record.prefixed_id,
        refund_method: 'store_credit'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('refunded')
      expect(Spree::StoreCredit.find_by(originator: return_record)).to be_present
    end

    it 'rejects an unknown refund method' do
      patch :refund, params: {
        order_id: order.prefixed_id,
        id: return_record.prefixed_id,
        refund_method: 'crypto'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #cancel' do
    it 'cancels a requested return' do
      return_record = create_return

      patch :cancel, params: { order_id: order.prefixed_id, id: return_record.prefixed_id, reason: 'Changed mind' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('canceled')
    end

    it 'refuses a return that was already received' do
      return_record = create(:received_return, store: store, order: order)

      patch :cancel, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'store isolation' do
    it 'does not expose an order from another store' do
      other_order = create(:shipped_order, store: create(:store))

      get :index, params: { order_id: other_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
