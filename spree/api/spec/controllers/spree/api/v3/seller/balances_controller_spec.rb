require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::BalancesController, type: :controller do
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

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  def earn(amount, currency: 'USD', status: 'completed')
    create(:seller_transfer, seller: seller, currency: currency, amount: amount, status: status,
                             order: create(:completed_order_with_totals, store: store, seller: seller, currency: currency))
  end

  describe 'GET #index' do
    it 'answers one position per currency' do
      earn(40)
      earn(10, status: 'pending')
      earn(30, currency: 'EUR')
      create(:seller_payout, :completed, seller: seller, amount: 15)
      # Another seller's ledger must not bleed in.
      create(:seller_transfer, :completed, seller: create(:seller, :approved, store: store), amount: 999)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      usd = json_response['data'].find { |row| row['currency'] == 'USD' }
      expect(json_response['data'].map { |row| row['currency'] }).to eq(%w[EUR USD])
      expect(usd).to include('earned' => '40.0', 'paid' => '15.0', 'balance' => '25.0', 'pending' => '10.0',
                             'display_balance' => '$25.00')
      expect(usd).not_to have_key('id')
    end

    it 'is empty before the first sale' do
      get :index, as: :json

      expect(json_response['data']).to eq([])
    end

    context 'without the ledger key' do
      let(:seller_role) do
        create(:role, name: 'Seller', resource: seller, permissions: %w[write_seller_profile])
      end

      it 'is refused' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
