require 'spec_helper'

# The team screen's whole loop over HTTP: invite, see it pending, resend,
# revoke — then invite again and accept, and watch it move from the pending
# list into the member list.
RSpec.describe 'Seller team management', type: :request do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:owner) { create(:admin_user, :without_admin_role).tap { |u| seller.add_user(u) } }
  let(:headers) do
    {
      'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(
        owner, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
      )}",
      'X-Spree-Seller-Id' => seller.prefixed_id
    }
  end

  def json = JSON.parse(response.body)

  it 'runs the loop the team screen drives' do
    post '/api/v3/seller/team', params: { email: 'hire@example.com' }, headers: headers
    expect(response).to have_http_status(:created)

    # The screen reads members and invitations separately: a new hire is not
    # a member until they accept.
    get '/api/v3/seller/team', headers: headers
    expect(json['data'].pluck('email')).not_to include('hire@example.com')

    get '/api/v3/seller/invitations', headers: headers
    pending = json['data'].first
    expect(pending['email']).to eq('hire@example.com')
    expect(pending['acceptance_url']).to be_present

    patch "/api/v3/seller/invitations/#{pending['id']}/resend", headers: headers
    expect(response).to have_http_status(:ok)

    delete "/api/v3/seller/invitations/#{pending['id']}", headers: headers
    expect(response).to have_http_status(:no_content)

    get '/api/v3/seller/invitations', headers: headers
    expect(json['data']).to be_empty
  end

  it 'moves an accepted invitation from pending into the team' do
    post '/api/v3/seller/team', params: { email: 'joiner@example.com' }, headers: headers
    invitation = Spree::Invitation.find_by(email: 'joiner@example.com')

    post "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/accept",
         params: { token: invitation.token, password: 'sekrit123', password_confirmation: 'sekrit123' }
    expect(response).to have_http_status(:ok)

    get '/api/v3/seller/invitations', headers: headers
    expect(json['data']).to be_empty

    get '/api/v3/seller/team', headers: headers
    expect(json['data'].pluck('email')).to include('joiner@example.com')
  end
end
