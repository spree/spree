require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:mine) { create(:completed_order_with_totals, store: store, seller: seller) }
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:completed_order_with_totals, store: store, seller: other_seller) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's orders" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      numbers = json_response['data'].map { |row| row['number'] }
      expect(numbers).to include(mine.number)
      expect(numbers).not_to include(theirs.number)
    end

    # A draft carrying its cart is a checkout still in flight; it is nobody's
    # order yet and must not appear in a seller's list.
    it 'leaves out a checkout still in flight' do
      cart = create(:cart, store: store)
      create(:order, store: store, seller: seller, status: 'draft', cart: cart)

      get :index, as: :json

      expect(json_response['data'].map { |row| row['status'] }).not_to include('draft')
    end
  end

  # A backoffice draft has no cart, so it passes the in-flight filter — but it
  # is the operator's working document, not something the seller has sold.
  describe 'operator drafts' do
    let!(:backoffice_draft) do
      create(:order, store: store, seller: seller, status: 'draft', cart: nil)
    end

    it 'are left out of the list' do
      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).
        not_to include(backoffice_draft.prefixed_id)
    end

    it 'cannot be read directly' do
      get :show, params: { id: backoffice_draft.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot be canceled' do
      patch :cancel, params: { id: backoffice_draft.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #show' do
    it 'renders what the seller needs to pack the parcel' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['number']).to eq(mine.number)
      expect(json_response).to have_key('items')
      expect(json_response).to have_key('shipping_address')
      # How the customer paid the marketplace is not the seller's business.
      expect(json_response).not_to have_key('payments')
    end

    it "404s on another seller's order" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #cancel' do
    it 'withdraws from an order it cannot fulfil' do
      patch :cancel, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload).to be_canceled
    end

    it "404s on another seller's order" do
      patch :cancel, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).not_to be_canceled
    end
  end
end
