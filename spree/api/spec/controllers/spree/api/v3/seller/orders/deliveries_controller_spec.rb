require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::DeliveriesController, type: :controller do
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

  it 'lists and records consignments on the seller own parcel' do
    get :index, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json
    expect(response).to have_http_status(:ok)
    expect(json_response['data'].first['tracking_number']).to eq(fulfillment.tracking)

    post :create, params: {
      order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, tracking_number: 'SELLER-1'
    }, as: :json

    expect(response).to have_http_status(:created)
    expect(fulfillment.reload.deliveries.count).to eq(2)
  end

  it 'corrects and removes a consignment' do
    delivery = fulfillment.deliveries.first

    patch :update, params: {
      order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
      id: delivery.prefixed_id, tracking_number: 'FIXED-1'
    }, as: :json
    expect(json_response['tracking_number']).to eq('FIXED-1')

    delete :destroy, params: {
      order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: delivery.prefixed_id
    }, as: :json
    expect(response).to have_http_status(:no_content)
  end

  # A fulfillment on somebody else's order reads as missing rather than
  # denied, whatever id the seller sends.
  it 'answers 404 for another seller order' do
    other = create(:order_ready_to_ship, store: store)

    get :index, params: { order_id: other.prefixed_id, fulfillment_id: other.fulfillments.first.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
