require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Sellers::BalancesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it "answers the seller's position per currency" do
      create(:seller_transfer, :completed, seller: seller, amount: 40,
                                           order: create(:completed_order_with_totals, store: store, seller: seller))
      create(:seller_payout, :completed, seller: seller, amount: 15)

      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row).to include('seller_id' => seller.prefixed_id, 'currency' => 'USD',
                             'balance' => '25.0', 'display_balance' => '$25.00')
    end

    it "404s on another marketplace's seller" do
      other = create(:seller, store: create(:store))

      get :index, params: { seller_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'with a role that may read sellers but not the ledger' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permissions) { %w[read_sellers] }

      it 'is refused' do
        get :index, params: { seller_id: seller.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
