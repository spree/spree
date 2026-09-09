require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::ExchangesController, type: :controller do
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
  let(:replacement) { create(:variant, seller: seller) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  def create_params(variant: replacement, order_record: order)
    {
      order_id: order_record.prefixed_id,
      items: [{
        fulfillment_item_id: order_record.fulfillment_items.first.prefixed_id,
        new_variant_id: variant.prefixed_id,
        quantity: 1
      }]
    }
  end

  describe 'POST #create' do
    it 'opens an exchange into the seller’s own catalogue' do
      post :create, params: create_params, as: :json

      expect(response).to have_http_status(:created)
      expect(order.exchanges.count).to eq(1)
    end

    # The replacement is stock this seller sends, so a rival's variant is not
    # theirs to promise — and reaching one here would put another seller's
    # goods on this order.
    it 'refuses a replacement variant belonging to another seller' do
      theirs = create(:variant, seller: other_seller)

      post :create, params: create_params(variant: theirs), as: :json

      expect(response).to have_http_status(:not_found)
      expect(order.exchanges).to be_empty
    end

    it 'cannot open an exchange on another seller’s order' do
      their_order = create(:shipped_order, store: store, seller: other_seller, line_items_count: 1)

      post :create, params: create_params(order_record: their_order), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'status moves' do
    let(:exchange) do
      Spree::Exchanges::Create.call(
        order: order,
        items: [{ fulfillment_item: fulfillment_item, new_variant: replacement, quantity: 1 }]
      ).value
    end

    it 'approves' do
      patch :approve, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(exchange.reload).to be_approved
    end

    it 'receives' do
      Spree::Exchanges::Approve.call(exchange: exchange)

      patch :receive, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(exchange.reload).to be_received
    end

    it 'fulfills, sending the replacement' do
      Spree::Exchanges::Approve.call(exchange: exchange)
      Spree::Exchanges::Receive.call(exchange: exchange)

      patch :fulfill, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(exchange.reload).to be_fulfilled
    end

    it 'cancels' do
      patch :cancel, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(exchange.reload).to be_canceled
    end
  end
end
