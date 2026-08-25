require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Sellers::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, store: store) }
  let(:invitation) do
    create(:invitation, resource: seller, role: seller.default_user_role, inviter: admin_user)
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists offers nobody has accepted' do
      invitation

      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to include(invitation.prefixed_id)
    end

    # An accepted invitation is a team member, which the team endpoint lists.
    it 'leaves out one that has been accepted' do
      invitation.update!(accepted_at: Time.current, status: 'accepted')

      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(json_response['data']).to be_empty
    end
  end

  describe 'DELETE #destroy' do
    it 'withdraws the offer' do
      delete :destroy, params: { seller_id: seller.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Invitation.find_by(id: invitation.id)).to be_nil
    end

    it 'refuses an invitation belonging to another seller' do
      other = create(:seller, store: store)
      stranger = create(:invitation, resource: other, role: other.default_user_role, inviter: admin_user)

      delete :destroy, params: { seller_id: seller.prefixed_id, id: stranger.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #resend' do
    # The mail is sent by a subscriber on the event, so the event is what this
    # endpoint is responsible for raising.
    it 'sends the offer again' do
      invitation # created before the expectation, so its own event is not caught
      expect_any_instance_of(Spree::Invitation).to receive(:publish_event).with('invitation.resent')

      patch :resend, params: { seller_id: seller.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'refuses once the offer has lapsed' do
      invitation.update_column(:expires_at, 1.day.ago)

      patch :resend, params: { seller_id: seller.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
