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

  describe 'PATCH #update' do
    it 'records a tracking number and its carrier' do
      patch :update, params: {
        order_id: order.prefixed_id, id: fulfillment.prefixed_id,
        tracking: 'TRACK123', tracking_carrier: 'ups'
      }, as: :json

      expect(response).to have_http_status(:ok)
      # Tracking lives on the parcel's consignment since 6.0; `tracking` and
      # `tracking_url` on the fulfillment summarize the primary one.
      expect(fulfillment.reload.tracking).to eq('TRACK123')
      expect(fulfillment.deliveries.first.carrier).to eq('ups')
      expect(fulfillment.tracking_url).to include('TRACK123')
    end

    # A seller picking from a different shelf than the split assumed needs to
    # say so, and the rate requotes from there.
    it 'moves the parcel to another of the seller’s shelves' do
      elsewhere = create(:stock_location, store: store, seller: seller)

      patch :update, params: {
        order_id: order.prefixed_id, id: fulfillment.prefixed_id,
        stock_location_id: elsewhere.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(fulfillment.reload.stock_location_id).to eq(elsewhere.id)
    end

    # The marketplace's own warehouses are not the seller's to ship from,
    # whatever id arrives.
    it 'refuses a shelf belonging to the marketplace' do
      theirs = create(:stock_location, store: store)
      original = fulfillment.stock_location_id

      patch :update, params: {
        order_id: order.prefixed_id, id: fulfillment.prefixed_id,
        stock_location_id: theirs.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(fulfillment.reload.stock_location_id).to eq(original)
    end
  end

  describe 'PATCH #cancel' do
    it 'cancels a parcel the seller will not send' do
      patch :cancel, params: { order_id: order.prefixed_id, id: fulfillment.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(fulfillment.reload).to be_canceled
    end

    # Resuming a canceled parcel was removed from the platform: the goods went
    # back on the shelf and the carrier was stood down, so the honest move is
    # a new parcel rather than reviving that one.
    it 'has no route for resuming one' do
      expect {
        patch :resume, params: { order_id: order.prefixed_id, id: fulfillment.prefixed_id }, as: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end

    it "404s cancelling through another seller's order" do
      other = create(:order_ready_to_ship, store: store, seller: create(:seller, :approved, store: store))

      patch :cancel, params: { order_id: other.prefixed_id, id: other.fulfillments.first.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other.fulfillments.first.reload).not_to be_canceled
    end
  end

  # Confirming receipt is deliberately not on this branch: a parcel having
  # arrived is the buyer's word, not the sender's.
  describe 'marking delivered' do
    it 'has no route' do
      expect {
        patch :mark_delivered, params: { order_id: order.prefixed_id, id: fulfillment.prefixed_id }, as: :json
      }.to raise_error(ActionController::UrlGenerationError)
    end
  end

  describe 'PATCH #split' do
    let!(:order) { create(:order_ready_to_ship, store: store, seller: seller, line_items_count: 2) }

    it 'moves part of the parcel onto one of its own' do
      variant = fulfillment.fulfillment_items.first.variant

      expect {
        patch :split, params: {
          order_id: order.prefixed_id, id: fulfillment.prefixed_id,
          variant_id: variant.prefixed_id, quantity: 1
        }, as: :json
      }.to change { order.fulfillments.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    # What may be split is what this parcel is carrying, so a variant from
    # elsewhere in the catalogue is not addressable here.
    it '404s on a variant the order does not carry' do
      patch :split, params: {
        order_id: order.prefixed_id, id: fulfillment.prefixed_id,
        variant_id: create(:variant, seller: seller).prefixed_id, quantity: 1
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a destination belonging to another seller' do
      variant = fulfillment.fulfillment_items.first.variant
      theirs = create(:stock_location, store: store, seller: create(:seller, :approved, store: store))

      patch :split, params: {
        order_id: order.prefixed_id, id: fulfillment.prefixed_id,
        variant_id: variant.prefixed_id, quantity: 1,
        stock_location_id: theirs.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
