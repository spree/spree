require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::NotesController, type: :controller do
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

  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:mine) { create(:completed_order_with_totals, store: store, seller: seller) }
  let!(:theirs) { create(:completed_order_with_totals, store: store, seller: other_seller) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #show' do
    it 'renders the notes on the order' do
      mine.update!(customer_note: 'Ring the bell')

      get :show, params: { order_id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['customer_note']).to eq('Ring the bell')
    end

    it "404s on another seller's order" do
      get :show, params: { order_id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    # A marketplace basket splits into one order per seller, so the note on
    # this row belongs to this seller alone.
    it 'records the seller’s own working note' do
      patch :update, params: {
        order_id: mine.prefixed_id, internal_note: '<p>Packed with the fragile insert.</p>'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.internal_note.to_s).to include('fragile insert')
    end

    it 'records what the buyer asked for' do
      patch :update, params: {
        order_id: mine.prefixed_id, customer_note: 'Leave with the neighbour'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.customer_note).to eq('Leave with the neighbour')
    end

    # An absent key leaves that note alone; only an empty string clears it.
    it 'leaves the note it was not sent' do
      mine.update!(customer_note: 'Ring the bell')

      patch :update, params: { order_id: mine.prefixed_id, internal_note: '<p>Noted.</p>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.customer_note).to eq('Ring the bell')
    end

    it 'clears a note sent as an empty string' do
      mine.update!(customer_note: 'Ring the bell')

      patch :update, params: { order_id: mine.prefixed_id, customer_note: '' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.customer_note).to be_blank
    end

    it 'refuses a request naming neither note' do
      patch :update, params: { order_id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s on another seller's order" do
      patch :update, params: {
        order_id: theirs.prefixed_id, internal_note: '<p>Nope.</p>'
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
