require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockLevelsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:stock_location) { create(:stock_location, store: store) }
  let!(:variant) { create(:variant) }

  before do
    request.headers.merge!(headers)
    variant.stock_levels.destroy_all
    create(:stock_level, variant: variant, stock_location: stock_location,
                        count_on_hand: 5, adjust_count_on_hand: false)
    variant.stock_levels.reload
  end

  def stock_level
    variant.stock_levels.find_by(stock_location: stock_location)
  end

  describe 'POST #bulk_upsert' do
    it 'sets the level a feed reports' do
      post :bulk_upsert, params: {
        stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id,
                        count_on_hand: 12 }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['stock_level_count']).to eq(1)
      expect(stock_level.count_on_hand).to eq(12)
    end

    # A merchant has to be able to see why a number moved, so a feed writes
    # history rather than overwriting the figure.
    it 'records the change as a movement rather than a silent overwrite' do
      expect do
        post :bulk_upsert, params: {
          stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id,
                          count_on_hand: 12 }]
        }, as: :json
      end.to change(Spree::StockMovement, :count).by(1)

      expect(Spree::StockMovement.last.quantity).to eq(7)
    end

    it 'accepts a relative adjustment as well as an absolute level' do
      post :bulk_upsert, params: {
        stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id,
                        adjustment: -2 }]
      }, as: :json

      expect(stock_level.count_on_hand).to eq(3)
    end

    it 'addresses records by the keys the external system holds' do
      variant.set_external_id('erp', 'MAT-100')
      stock_location.set_external_id('erp', 'WH-1')

      post :bulk_upsert, params: {
        stock_levels: [{ variant: { external_id: { erp: 'MAT-100' } },
                        stock_location: { external_id: { erp: 'WH-1' } },
                        count_on_hand: 9 }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock_level.count_on_hand).to eq(9)
    end

    it 'writes many pairs in one call' do
      second = create(:variant)
      second.stock_levels.destroy_all
      create(:stock_level, variant: second, stock_location: stock_location, count_on_hand: 0,
                          adjust_count_on_hand: false)

      post :bulk_upsert, params: {
        stock_levels: [
          { variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id, count_on_hand: 1 },
          { variant_id: second.prefixed_id, stock_location_id: stock_location.prefixed_id, count_on_hand: 2 }
        ]
      }, as: :json

      expect(json_response['stock_level_count']).to eq(2)
      expect(stock_level.count_on_hand).to eq(1)
      expect(second.stock_levels.find_by(stock_location: stock_location).count_on_hand).to eq(2)
    end

    it 'sets the backorder flag when the feed states it' do
      post :bulk_upsert, params: {
        stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id,
                        count_on_hand: 5, backorderable: false }]
      }, as: :json

      expect(stock_level.backorderable).to be(false)
    end

    it 'rejects a row that names neither a level nor an adjustment' do
      post :bulk_upsert, params: {
        stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['rows'].first['missing']).to include('count_on_hand')
    end

    it 'refuses to write another store stock' do
      other_store = create(:store)
      other_location = create(:stock_location, store: other_store)

      post :bulk_upsert, params: {
        stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: other_location.prefixed_id,
                        count_on_hand: 99 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(stock_level.count_on_hand).to eq(5)
    end

    it 'asks for the parameter rather than silently doing nothing' do
      post :bulk_upsert, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('missing_stock_levels')
    end

    it 'accepts an empty batch as a no-op' do
      post :bulk_upsert, params: { stock_levels: [] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['stock_level_count']).to eq(0)
    end
  end
end
