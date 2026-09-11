require 'spec_helper'

# A seller reads their own earnings and never anyone else's: the isolation is
# the scope, so another seller's row is a 404 rather than a 403.
RSpec.describe Spree::Api::V3::Seller::TransfersController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  # A role holding only the ledger key, so the catalog entry is what lets
  # these requests through.
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_seller_earnings])
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let(:order) { create(:completed_order_with_totals, store: store, seller: seller) }
  let!(:mine) { create(:seller_transfer, :completed, seller: seller, order: order, amount: 42) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) do
    create(:seller_transfer, seller: other_seller, order: create(:completed_order_with_totals, store: store, seller: other_seller))
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists this seller's earnings and nobody else's" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(json_response['data'].map { |transfer| transfer['id'] }).to contain_exactly(mine.prefixed_id)
      expect(row['amount']).to eq('42.0')
      expect(row['display_amount']).to eq('$42.00')
      expect(row['order_number']).to eq(order.number)
      expect(row['order_id']).to eq(order.prefixed_id)
      expect(row).not_to have_key('metadata')
      expect(row).not_to have_key('refund_id')
      expect(row).not_to have_key('seller_name')
    end

    it 'filters to one order' do
      other_order = create(:completed_order_with_totals, store: store, seller: seller)
      create(:seller_transfer, seller: seller, order: other_order)

      get :index, params: { q: { order_id_eq: other_order.prefixed_id } }, as: :json

      expect(json_response['data'].map { |transfer| transfer['order_id'] }).to eq([other_order.prefixed_id])
    end

    it 'filters to the earnings one settlement covers' do
      payout = create(:seller_payout, seller: seller)
      settled = create(:seller_transfer, :completed, seller: seller, payout: payout,
                                                     order: create(:completed_order_with_totals, store: store, seller: seller))

      get :index, params: { q: { payout_id_eq: payout.prefixed_id } }, as: :json

      expect(json_response['data'].map { |transfer| transfer['id'] }).to eq([settled.prefixed_id])
    end

    context 'without the ledger key' do
      let(:seller_role) do
        create(:role, name: 'Seller', resource: seller, permissions: %w[write_orders write_seller_profile])
      end

      it 'is refused' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #show' do
    it 'renders one of their own' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(mine.prefixed_id)
      expect(json_response['status']).to eq('completed')
    end

    it "404s on another seller's" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
