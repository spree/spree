require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ClaimsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:line_item) { order.line_items.first }

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'opens a claim' do
      post :create, params: {
        order_id: order.prefixed_id,
        memo: 'Arrived cracked',
        items: [{ line_item_id: line_item.prefixed_id, quantity: 1, description: 'Cracked screen' }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('open')
      expect(json_response['number']).to start_with('CLM')
    end

    it 'records a reason from the store' do
      reason = create(:claim_reason, store: store)

      post :create, params: {
        order_id: order.prefixed_id,
        reason_id: reason.prefixed_id,
        items: [{ line_item_id: line_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['reason_id']).to eq(reason.prefixed_id)
    end

    it 'rejects a reason belonging to another store' do
      foreign = create(:claim_reason, store: create(:store))

      post :create, params: {
        order_id: order.prefixed_id,
        reason_id: foreign.prefixed_id,
        items: [{ line_item_id: line_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #approve' do
    it 'approves an open claim' do
      claim = create(:claim, store: store, order: order)

      patch :approve, params: { order_id: order.prefixed_id, id: claim.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('approved')
    end
  end

  describe 'PATCH #resolve' do
    let(:claim) { create(:approved_claim, store: store, order: order) }

    it 'resolves with a store credit refund' do
      patch :resolve, params: {
        order_id: order.prefixed_id,
        id: claim.prefixed_id,
        resolution: 'refund',
        refund_method: 'store_credit'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('resolved')
      expect(json_response['resolution']).to eq('refund')
      expect(Spree::StoreCredit.find_by(originator: claim)).to be_present
    end

    # A claim opened without per-item amounts has nothing to refund; the
    # dashboard collects them at creation, and the API says so plainly.
    it 'refuses a refund when no amount was recorded on the claim' do
      empty = create(:claim, store: store, order: order)
      empty.claim_line_items.each { |line| line.update!(refund_amount: 0) }
      Spree::Claims::Approve.call(claim: empty)

      patch :resolve, params: {
        order_id: order.prefixed_id,
        id: empty.prefixed_id,
        resolution: 'refund'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # The merchant decides what to send when resolving, so a claim opened
    # without replacement flags can still be resolved with one.
    it 'sends a replacement for the lines chosen at resolve time' do
      line = claim.claim_line_items.first
      line.update!(send_replacement: false)
      line.variant.stock_items.first&.set_count_on_hand(10)

      patch :resolve, params: {
        order_id: order.prefixed_id,
        id: claim.prefixed_id,
        resolution: 'replacement',
        replacement_line_item_ids: [line.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('resolved')
      expect(line.reload.send_replacement).to be(true)
    end

    it 'rejects an unknown resolution' do
      patch :resolve, params: {
        order_id: order.prefixed_id,
        id: claim.prefixed_id,
        resolution: 'apologize'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #deny' do
    it 'denies an open claim with a reason' do
      claim = create(:claim, store: store, order: order)

      patch :deny, params: {
        order_id: order.prefixed_id,
        id: claim.prefixed_id,
        reason: 'Outside warranty'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('denied')
    end
  end
end
