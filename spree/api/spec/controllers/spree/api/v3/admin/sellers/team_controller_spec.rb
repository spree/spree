require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Sellers::TeamController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, store: store) }
  let(:member) { create(:admin_user) }

  before do
    request.headers.merge!(headers)
    seller.add_user(member)
  end

  describe 'GET #index' do
    it 'lists who runs the seller' do
      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].find { |member_row| member_row['id'] == member.prefixed_id }
      expect(row['email']).to eq(member.email)
    end

    # A seller belonging to another marketplace is not this operator's to read,
    # and reads as missing rather than as denied.
    it 'refuses a seller from another store' do
      other = create(:seller, store: create(:store))

      get :index, params: { seller_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'revokes a member' do
      delete :destroy, params: { seller_id: seller.prefixed_id, id: member.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(seller.reload.users).not_to include(member)
    end

    it 'refuses a member of another seller' do
      stranger = create(:admin_user)
      create(:seller, store: store).add_user(stranger)

      delete :destroy, params: { seller_id: seller.prefixed_id, id: stranger.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
