require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::FulfillmentsController, type: :controller do
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

  let!(:order) { create(:order_ready_to_ship, store: store, seller: seller) }
  let(:fulfillment) { order.fulfillments.first }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it 'lists what the seller owes on the order' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to include(fulfillment.prefixed_id)
    end

    it "404s on another seller's order" do
      other = create(:order_ready_to_ship, store: store, seller: create(:seller, :approved, store: store))

      get :index, params: { order_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # A draft is not an order this seller has sold, so it must be as
    # unreachable here as it is on the orders endpoint itself — otherwise
    # the nested route becomes a way around that filter.
    it '404s on a draft' do
      draft = create(:order, store: store, seller: seller, status: 'draft', cart: nil)

      get :index, params: { order_id: draft.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #fulfill' do
    it 'ships the parcel' do
      patch :fulfill,
            params: { order_id: order.prefixed_id, id: fulfillment.prefixed_id, tracking: 'TRACK-1' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(fulfillment.reload).to be_fulfilled
      expect(fulfillment.tracking).to eq('TRACK-1')
    end

    # A line the parcel does not hold cannot be shipped out of it, even when
    # another parcel on the same order does hold it — the request is checked
    # against this fulfillment alone, before anything is split or shipped.
    it 'refuses a line this parcel does not hold' do
      other = order.fulfillments.create!(stock_location: fulfillment.stock_location)
      moved = fulfillment.fulfillment_items.first
      moved.update!(fulfillment: other)

      patch :fulfill,
            params: {
              order_id: order.prefixed_id,
              id: fulfillment.prefixed_id,
              items: [{ item_id: moved.line_item.prefixed_id, quantity: moved.quantity }]
            },
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(fulfillment.reload).not_to be_fulfilled
      expect(other.reload).not_to be_fulfilled
      expect(moved.reload.fulfillment_id).to eq(other.id)
    end

    # Shipping through another seller's order must be unreachable whatever ids
    # are sent, since the fulfillment is only ever found through the order.
    it "404s on a fulfillment reached through someone else's order" do
      other = create(:order_ready_to_ship, store: store, seller: create(:seller, :approved, store: store))
      theirs = other.fulfillments.first

      patch :fulfill, params: { order_id: order.prefixed_id, id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).not_to be_fulfilled
    end
  end
end
