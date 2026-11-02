require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::InvoicesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) { create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) } }
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER)
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
    2.times { create(:invoice, order: create(:shipped_order, store: store, seller: seller, line_items_count: 1)) }
    create(:invoice, :commission, seller_payout: create(:seller_payout, seller: seller, store: store))
  end

  describe 'GET #index' do
    it "lists the seller's invoices and commission invoices only" do
      create(:invoice, order: create(:shipped_order, store: store, seller: create(:seller, store: store), line_items_count: 1))

      get :index, as: :json

      expect(json_response['data'].size).to eq(3)
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, as: :json }
    end
  end
end
