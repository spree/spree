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

  # An order is created by a shopper checking out, never by the seller. The
  # branch routes no write verb at all, so widening `resources :orders` would
  # have to trip this rather than silently hand sellers a draft to author.
  describe 'writing an order' do
    it 'is not routable' do
      expect(post: '/api/v3/seller/orders').not_to be_routable
      expect(patch: '/api/v3/seller/orders/ord_x').not_to be_routable
      expect(delete: '/api/v3/seller/orders/ord_x').not_to be_routable
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

    # The seller is merchant of record for their child order, so they invoice
    # the buyer and need the billing address to do it — both marketplace
    # platforms we surveyed give a seller the same two addresses.
    it 'carries the addresses the seller ships and invoices to' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(json_response).to include('shipping_address', 'billing_address')
    end

    # A phone on the shipping address is how a seller reaches a buyer about a
    # delivery. An email is what takes a marketplace's customer off it, and
    # packing, posting and invoicing need none.
    it "withholds the buyer's email" do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(json_response).not_to have_key('email')
      expect(json_response['shipping_address']).to have_key('phone')
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

  describe 'PATCH #cancel with a reason' do
    let!(:order) { create(:completed_order_with_totals, store: store, seller: seller) }
    let(:reason) { create(:order_cancellation_reason, store: store, name: 'Out of stock') }

    it 'records the reason and note the seller picked' do
      patch :cancel, params: {
        id: order.prefixed_id,
        cancel_reason_id: reason.prefixed_id,
        cancel_note: 'Supplier let us down'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.cancel_reason).to eq(reason)
      expect(order.cancel_note).to eq('Supplier let us down')
    end

    # The vocabulary is the marketplace's, and a reason from another store
    # would label this order with words its operator never chose.
    it 'refuses a reason belonging to another store' do
      elsewhere = create(:order_cancellation_reason, store: create(:store), name: 'Elsewhere')

      patch :cancel, params: { id: order.prefixed_id, cancel_reason_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(order.reload).not_to be_canceled
    end

    # Releasing the authorization is the cancel's job; giving back money
    # already taken is the operator's, so the seller endpoint passes no refund
    # arguments at all and the workflow's default holds.
    it 'refunds nothing' do
      expect {
        patch :cancel, params: { id: order.prefixed_id }, as: :json
      }.not_to change(Spree::Refund, :count)

      expect(order.reload).to be_canceled
    end
  end
end
