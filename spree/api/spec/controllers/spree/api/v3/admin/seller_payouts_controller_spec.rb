require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellerPayoutsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let!(:payout) { create(:seller_payout, seller: seller, amount: 120, currency: 'USD') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists what a seller is owed' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('vpo_')
      expect(row['seller_name']).to eq('Sparks Audio')
      expect(row['amount']).to eq('120.0')
      expect(row['display_amount']).to eq('$120.00')
      expect(row['status']).to eq('pending')
    end

    it "hides another marketplace's settlements" do
      create(:seller_payout, seller: create(:seller, store: create(:store)))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).to contain_exactly(payout.prefixed_id)
    end

    it 'counts the earnings a settlement covers' do
      create(:seller_transfer, :completed, seller: seller, payout: payout)
      create(:seller_transfer, :completed, seller: seller, payout: payout)

      get :index, as: :json

      expect(json_response['data'].first['transfers_count']).to eq(2)
    end
  end

  describe 'PATCH #complete' do
    it 'records that the money landed' do
      patch :complete, params: { id: payout.prefixed_id, reference: 'BACS-9912' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
      expect(payout.reload.reference).to eq('BACS-9912')
    end

    it "404s on another marketplace's settlement" do
      other = create(:seller_payout, seller: create(:seller, store: create(:store)))

      patch :complete, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'still reports how many earnings the settlement covers' do
      create(:seller_transfer, :completed, seller: seller, payout: payout)
      create(:seller_transfer, :completed, seller: seller, payout: payout)

      patch :complete, params: { id: payout.prefixed_id }, as: :json

      expect(json_response['transfers_count']).to eq(2)
    end

    # The page-wide count belongs to the listing, and building it runs the
    # whole paginated index query. Doing that to serialize one record is waste
    # on every call, and answers from a page this settlement need not be on.
    it 'does not run the listing query to serialize one settlement' do
      expect(controller).not_to receive(:collection)

      patch :complete, params: { id: payout.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'writes' do
    it 'offers no create — a settlement is produced by the sweep' do
      expect { post :create, params: { amount: 5 }, as: :json }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
