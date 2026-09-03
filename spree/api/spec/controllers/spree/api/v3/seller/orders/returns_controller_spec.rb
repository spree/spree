require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::ReturnsController, type: :controller do
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

  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:fulfillment_item) { order.fulfillment_items.first }

  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:their_order) { create(:shipped_order, store: store, seller: other_seller, line_items_count: 1) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  def open_return(on: order)
    Spree::Returns::Create.call(
      order: on,
      items: [{ fulfillment_item: on.fulfillment_items.first, quantity: 1 }]
    ).value
  end

  describe 'POST #create' do
    it 'opens a return on the seller’s own order' do
      post :create, params: {
        order_id: order.prefixed_id,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(order.returns.count).to eq(1)
    end

    it 'records the seller user who filed it' do
      post :create, params: {
        order_id: order.prefixed_id,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(order.returns.last.created_by).to eq(seller_user)
    end

    # Tenancy is the fetch: another seller's order is not found here, so it
    # reads as missing rather than denied.
    it 'cannot open a return on another seller’s order' do
      post :create, params: {
        order_id: their_order.prefixed_id,
        items: [{ fulfillment_item_id: their_order.fulfillment_items.first.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(their_order.returns).to be_empty
    end

    it 'refuses a stock location belonging to another seller' do
      their_location = create(:stock_location, store: store, seller: other_seller)

      post :create, params: {
        order_id: order.prefixed_id,
        stock_location_id: their_location.prefixed_id,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    it 'lists returns on the order' do
      open_return

      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
    end

    it 'cannot read returns on another seller’s order' do
      open_return(on: their_order)

      get :index, params: { order_id: their_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'status moves' do
    let(:return_record) { open_return }

    it 'approves' do
      patch :approve, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(return_record.reload).to be_approved
    end

    it 'receives' do
      Spree::Returns::Approve.call(return_record: return_record)

      patch :receive, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(return_record.reload).to be_received
    end

    it 'cancels' do
      patch :cancel, params: { order_id: order.prefixed_id, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(return_record.reload).to be_canceled
    end

    # The money half. A seller is merchant of record for their own child
    # order, so refunding it is theirs — see the seller order management plan.
    describe 'refunding' do
      before do
        Spree::Returns::Approve.call(return_record: return_record)
        Spree::Returns::Receive.call(return_record: return_record)
        allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)
      end

      it 'refunds to store credit' do
        patch :refund, params: {
          order_id: order.prefixed_id, id: return_record.prefixed_id,
          refund_method: 'store_credit'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(return_record.reload).to be_refunded
      end

      it 'refuses more than the return is owed' do
        patch :refund, params: {
          order_id: order.prefixed_id, id: return_record.prefixed_id,
          refund_method: 'store_credit', amount: 10_000
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(return_record.reload).not_to be_refunded
      end
    end
  end

  describe 'authorization' do
    # A seller whose role carries only the read key may look but not file.
    it 'refuses to open a return without the write key' do
      allow(controller).to receive(:current_ability).
        and_return(Spree::Ability.new(seller_user, resource: seller).tap do |ability|
          ability.cannot :create, Spree::Return
        end)

      post :create, params: {
        order_id: order.prefixed_id,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
