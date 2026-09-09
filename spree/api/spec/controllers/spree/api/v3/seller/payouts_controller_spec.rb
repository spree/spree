require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::PayoutsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_seller_earnings])
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:mine) { create(:seller_payout, seller: seller, amount: 120, reference: 'BACS-1') }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:seller_payout, seller: other_seller) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists this seller's settlements and nobody else's" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |payout| payout['id'] }).to contain_exactly(mine.prefixed_id)
      row = json_response['data'].first
      expect(row['display_amount']).to eq('$120.00')
      expect(row['status']).to eq('pending')
      expect(row['reference']).to eq('BACS-1')
      expect(row).not_to have_key('seller_name')
      expect(row).not_to have_key('metadata')
    end

    it 'counts the earnings a settlement covers' do
      2.times do
        create(:seller_transfer, :completed, seller: seller, payout: mine,
                                             order: create(:completed_order_with_totals, store: store, seller: seller))
      end

      get :index, as: :json

      expect(json_response['data'].first['transfers_count']).to eq(2)
    end

    it 'filters by status' do
      settled = create(:seller_payout, :completed, seller: seller)

      get :index, params: { q: { status_eq: 'completed' } }, as: :json

      expect(json_response['data'].map { |payout| payout['id'] }).to eq([settled.prefixed_id])
    end

    context 'without the ledger key' do
      let(:seller_role) do
        create(:role, name: 'Seller', resource: seller, permissions: %w[write_orders])
      end

      it 'is refused' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #show' do
    it 'renders one of their own, counting its earnings' do
      create(:seller_transfer, :completed, seller: seller, payout: mine,
                                           order: create(:completed_order_with_totals, store: store, seller: seller))

      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(mine.prefixed_id)
      expect(json_response['transfers_count']).to eq(1)
    end

    it "404s on another seller's" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
