require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellerTransfersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let(:order) { create(:order, store: store, seller: seller) }
  let!(:transfer) do
    create(:seller_transfer, seller: seller, order: order, amount: 42.5, currency: 'USD')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists what a seller earned' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('vtr_')
      expect(row['seller_name']).to eq('Sparks Audio')
      expect(row['order_number']).to eq(order.number)
      expect(row['amount']).to eq('42.5')
      expect(row['display_amount']).to eq('$42.50')
      expect(row['kind']).to eq('earning')
    end

    it "hides another marketplace's ledger" do
      other_store = create(:store)
      other_seller = create(:seller, store: other_store)
      create(:seller_transfer, seller: other_seller, order: create(:order, store: other_store, seller: other_seller))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).to contain_exactly(transfer.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns one transfer' do
      get :show, params: { id: transfer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(transfer.prefixed_id)
    end

    it "404s on another marketplace's transfer" do
      other_store = create(:store)
      other_seller = create(:seller, store: other_store)
      other = create(:seller_transfer, seller: other_seller,
                                       order: create(:order, store: other_store, seller: other_seller))

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'writes' do
    it 'offers none — a transfer records money that moved' do
      expect { post :create, params: { amount: 5 }, as: :json }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
