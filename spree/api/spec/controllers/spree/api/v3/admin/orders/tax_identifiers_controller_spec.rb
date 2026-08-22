require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::TaxIdentifiersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns the snapshot with the verdict and the evidence behind it' do
      create(:tax_identifier, :on_order, :verified, owner: order, kind: 'eu_vat', value: 'DE123456789')

      get :show, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['kind']).to eq('eu_vat')
      expect(json_response['value']).to eq('DE123456789')
      # The fields the store serializer withholds — why staff come here.
      expect(json_response['validation_status']).to eq('verified')
      expect(json_response['validation_evidence']['registry']).to eq('vies')
      expect(json_response['source']).to eq('customer')
      expect(json_response['order_id']).to eq(order.prefixed_id)
    end

    it '404s on a consumer sale, which carries no registration' do
      get :show, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s on an order from another store' do
      other_order = create(:completed_order_with_totals, store: create(:store))
      create(:tax_identifier, :on_order, owner: other_order)

      get :show, params: { order_id: other_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'does not route a write — the snapshot is what the invoice says' do
    expect {
      patch :update, params: { order_id: order.prefixed_id, value: 'DE999999999' }, as: :json
    }.to raise_error(ActionController::UrlGenerationError)
  end
end
