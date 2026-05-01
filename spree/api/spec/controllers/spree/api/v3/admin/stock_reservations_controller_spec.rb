require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockReservationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:order) { create(:order, store: store) }
  let(:other_order) { create(:order, store: create(:store)) }

  let!(:reservation) { create(:stock_reservation, order: order, expires_at: 5.minutes.from_now) }
  let!(:other_store_reservation) { create(:stock_reservation, order: other_order, expires_at: 5.minutes.from_now) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns reservations scoped to the current store' do
      subject
      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |r| r['id'] }
      expect(ids).to include(reservation.prefixed_id)
      expect(ids).not_to include(other_store_reservation.prefixed_id)
    end

    it 'serializes reservation with prefixed associations and active flag' do
      subject
      record = json_response['data'].find { |r| r['id'] == reservation.prefixed_id }
      expect(record['stock_item_id']).to eq(reservation.stock_item.prefixed_id)
      expect(record['line_item_id']).to eq(reservation.line_item.prefixed_id)
      expect(record['order_id']).to eq(reservation.order.prefixed_id)
      expect(record['variant_id']).to eq(reservation.stock_item.variant.prefixed_id)
      expect(record['stock_location_id']).to eq(reservation.stock_item.stock_location.prefixed_id)
      expect(record['quantity']).to eq(reservation.quantity)
      expect(record['active']).to be(true)
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: reservation.prefixed_id }, as: :json }

    it 'returns the reservation' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(reservation.prefixed_id)
    end

    it 'returns 404 for a reservation in another store' do
      get :show, params: { id: other_store_reservation.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'write actions are not routed' do
    it 'POST #create has no route' do
      expect { post :create, as: :json }.to raise_error(ActionController::UrlGenerationError)
    end

    it 'PATCH #update has no route' do
      expect { patch :update, params: { id: reservation.prefixed_id }, as: :json }
        .to raise_error(ActionController::UrlGenerationError)
    end

    it 'DELETE #destroy has no route' do
      expect { delete :destroy, params: { id: reservation.prefixed_id }, as: :json }
        .to raise_error(ActionController::UrlGenerationError)
    end
  end
end
