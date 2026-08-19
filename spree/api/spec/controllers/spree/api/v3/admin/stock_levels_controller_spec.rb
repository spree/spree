require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockLevelsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:stock_location) { Spree::StockLocation.first || create(:stock_location) }
  let!(:variant) { create(:variant) }
  let!(:stock_level) { variant.stock_levels.find_by(stock_location: stock_location) || create(:stock_level, variant: variant, stock_location: stock_location) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns stock items' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |s| s['id'] }).to include(stock_level.prefixed_id)
    end

    it 'filters by stock_location_id' do
      other_location = create(:stock_location)
      _other_item = create(:stock_level, stock_location: other_location)

      get :index, params: { q: { stock_location_id_eq: stock_location.id } }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |s| s['id'] }
      expect(ids).to include(stock_level.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'updates count_on_hand' do
      patch :update, params: { id: stock_level.prefixed_id, count_on_hand: 42 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_level.reload.count_on_hand).to eq(42)
    end

    # The correction goes in the stock history like every other change, and
    # what it records is the delta — the column follows from it.
    it 'records the edit as an adjustment carrying the delta' do
      count_before = stock_level.count_on_hand

      patch :update, params: { id: stock_level.prefixed_id, count_on_hand: 42 }, as: :json

      movement = stock_level.stock_movements.adjusted.last
      expect(movement.kind).to eq('adjusted')
      expect(movement.quantity).to eq(42 - count_before)
    end

    # `to_i` reads anything unparseable as zero, and a zero here is not a
    # no-op — it is an instruction to write the whole shelf off.
    it 'refuses a count that is not a whole number instead of zeroing the shelf' do
      count_before = stock_level.count_on_hand

      expect {
        patch :update, params: { id: stock_level.prefixed_id, count_on_hand: 'invalid' }, as: :json
      }.not_to change { stock_level.reload.count_on_hand }.from(count_before)

      expect(response).to have_http_status(:unprocessable_content)
      expect(stock_level.stock_movements.adjusted).to be_empty
    end

    it 'stores a client-supplied reason on the movement' do
      patch :update, params: { id: stock_level.prefixed_id, count_on_hand: 42, reason: 'Damaged in transit' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_level.reload.count_on_hand).to eq(42)
      expect(stock_level.stock_movements.adjusted.last.reason).to eq('Damaged in transit')
    end

    it 'labels an unlabelled correction in English' do
      patch :update, params: { id: stock_level.prefixed_id, count_on_hand: 42 }, as: :json

      expect(stock_level.stock_movements.adjusted.last.reason).to eq('Manual adjustment')
    end

    it 'rejects a negative count' do
      patch :update, params: { id: stock_level.prefixed_id, count_on_hand: -1 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(stock_level.reload.count_on_hand).not_to eq(-1)
    end

    it 'toggles backorderable' do
      patch :update, params: { id: stock_level.prefixed_id, backorderable: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_level.reload.backorderable).to be true
    end

    it 'ignores variant_id and stock_location_id' do
      other_variant = create(:variant)
      other_location = create(:stock_location)

      patch :update, params: {
        id: stock_level.prefixed_id,
        variant_id: other_variant.prefixed_id,
        stock_location_id: other_location.prefixed_id,
        count_on_hand: 7
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_level.reload.variant_id).to eq(variant.id)
      expect(stock_level.stock_location_id).to eq(stock_location.id)
      expect(stock_level.count_on_hand).to eq(7)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the stock item' do
      target = create(:stock_level, stock_location: create(:stock_location))

      expect { delete :destroy, params: { id: target.prefixed_id }, as: :json }.
        to change(Spree::StockLevel, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
