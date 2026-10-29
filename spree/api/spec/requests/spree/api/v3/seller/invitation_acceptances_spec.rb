require 'spec_helper'

RSpec.describe 'Accepting a seller invitation on the Seller API', type: :request do
  include_context 'API v3 Seller'

  let(:password) { 'password123' }
  # Staff of another seller, invited to this one.
  let(:invitee) { create(:admin_user, :without_admin_role, password: password, password_confirmation: password) }
  let!(:invitation) do
    create(:invitation, resource: seller, inviter: seller_user, email: invitee.email, role: seller.default_user_role)
  end

  def accept(params = {}, headers: {})
    post "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/accept",
         params: { token: invitation.token }.merge(params), headers: headers
  end

  def bearer(user)
    token = Spree::Api::V3::TestingSupport.generate_jwt(
      user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  it 'accepts without a password when signed in as the invitee' do
    expect { accept(headers: bearer(invitee)) }.to change(Spree::RoleUser, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['user']['email']).to eq(invitee.email)
    expect(invitation.reload.status).to eq('accepted')
  end

  it 'matches the signed-in account to the invited address regardless of case' do
    invitation.update_column(:email, invitee.email.upcase)

    accept(headers: bearer(invitee))

    expect(response).to have_http_status(:ok)
    expect(invitation.reload.status).to eq('accepted')
  end

  it 'still asks for the password when signed in as another account' do
    other_account = bearer(seller_user)

    expect { accept(headers: other_account) }.not_to change(Spree::RoleUser, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(Spree::Invitation.pending.exists?(invitation.id)).to be(true)
  end

  it 'ignores an admin panel token, which was not issued for this API' do
    token = Spree::Api::V3::TestingSupport.generate_jwt(
      invitee, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
    )

    accept(headers: { 'Authorization' => "Bearer #{token}" })

    expect(response).to have_http_status(:unauthorized)
  end

  it 'reports whether the invitee already has an account' do
    get "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/lookup", params: { token: invitation.token }

    body = JSON.parse(response.body)
    expect(body['invitee_exists']).to be(true)
    expect(body['seller']).to eq('id' => seller.prefixed_id, 'name' => seller.name)
  end
end
