require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::ClaimsController, type: :controller do
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
  let(:line_item) { order.line_items.first }
  let(:other_seller) { create(:seller, :approved, store: store) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  def open_claim
    Spree::Claims::Create.call(
      order: order, items: [{ line_item: line_item, quantity: 1 }]
    ).value
  end

  describe 'POST #create' do
    it 'opens a claim on the seller’s own order' do
      post :create, params: {
        order_id: order.prefixed_id,
        items: [{ line_item_id: line_item.prefixed_id, quantity: 1, description: 'Arrived broken' }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(order.claims.count).to eq(1)
    end

    it 'refuses a replacement variant belonging to another seller' do
      theirs = create(:variant, seller: other_seller)

      post :create, params: {
        order_id: order.prefixed_id,
        items: [{
          line_item_id: line_item.prefixed_id, quantity: 1,
          send_replacement: true, replacement_variant_id: theirs.prefixed_id
        }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(order.claims).to be_empty
    end

    it 'cannot open a claim on another seller’s order' do
      their_order = create(:shipped_order, store: store, seller: other_seller, line_items_count: 1)

      post :create, params: {
        order_id: their_order.prefixed_id,
        items: [{ line_item_id: their_order.line_items.first.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'status moves' do
    let(:claim) { open_claim }

    it 'approves' do
      patch :approve, params: { order_id: order.prefixed_id, id: claim.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(claim.reload).to be_approved
    end

    it 'denies' do
      patch :deny, params: { order_id: order.prefixed_id, id: claim.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(claim.reload).to be_denied
    end

    it 'cancels' do
      patch :cancel, params: { order_id: order.prefixed_id, id: claim.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(claim.reload).to be_canceled
    end

    it 'resolves with a refund' do
      Spree::Claims::Approve.call(claim: claim)
      allow_any_instance_of(Spree::Refund).to receive(:perform!).and_return(true)

      patch :resolve, params: {
        order_id: order.prefixed_id, id: claim.prefixed_id,
        resolution: 'refund', refund_method: 'store_credit', amount: 5
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(claim.reload).to be_resolved
    end
  end
end
