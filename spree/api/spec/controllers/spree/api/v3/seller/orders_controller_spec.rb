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

  # A seller is merchant of record for their own child order, so a delivery
  # address the buyer got wrong is theirs to correct.
  describe 'PATCH #address' do
    it 'corrects the shipping address, keeping the lines it was not sent' do
      original = mine.ship_address
      original_line = original.address1

      patch :address, params: {
        id: mine.prefixed_id,
        shipping_address: { address1: '9 Corrected Way', city: 'Fixedton' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      address = mine.reload.ship_address
      expect(address.address1).to eq('9 Corrected Way')
      expect(address.city).to eq('Fixedton')
      # A request naming two lines must not blank out the rest of the address.
      expect(address.country_code).to eq(original.country_code)
      expect(address.postal_code).to eq(original.postal_code)
      # The order points at a new row: an order-level fix is not a rewrite of
      # the address the customer may also have saved in their own book.
      expect(address.id).not_to eq(original.id)
      expect(original.reload.address1).to eq(original_line)
    end

    it 'corrects the billing address' do
      patch :address, params: {
        id: mine.prefixed_id,
        billing_address: { address1: '4 Invoice Street' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.bill_address.address1).to eq('4 Invoice Street')
    end

    # Nothing else about the order is the seller's to write, so an attribute
    # that is not one of the two addresses is simply not read.
    it 'ignores anything that is not an address' do
      original_total = mine.total

      patch :address, params: {
        id: mine.prefixed_id,
        shipping_address: { city: 'Fixedton' },
        total: '0.01',
        customer_note: 'rewritten'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.total).to eq(original_total)
    end

    it 'refuses a request naming neither address' do
      patch :address, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s on another seller's order" do
      patch :address, params: {
        id: theirs.prefixed_id, shipping_address: { city: 'Fixedton' }
      }, as: :json

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

    # A seller is merchant of record for their own child order, so the party
    # who owes the buyer their money back is the party who took it.
    it 'hands back what the buyer paid when asked' do
      patch :cancel, params: { id: mine.prefixed_id, refund_payments: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload).to be_canceled
    end

    # The seller decides whether to refund, never how much: withdrawing from
    # the whole order returns what that order was paid.
    it 'ignores a partial amount the seller names' do
      expect(Spree.order_cancel_workflow).to receive(:call).
        with(hash_excluding(:refund_amount)).
        and_return(Spree::ServiceModule::Result.new(true, mine))

      patch :cancel, params: {
        id: mine.prefixed_id, refund_payments: true, refund_amount: '1.00'
      }, as: :json

      expect(response).to have_http_status(:ok)
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
