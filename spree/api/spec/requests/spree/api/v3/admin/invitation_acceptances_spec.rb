require 'spec_helper'

RSpec.describe 'Accepting a staff invitation on the Admin API', type: :request do
  include_context 'API v3 Admin'

  let(:password) { 'password123' }
  # Staff of another store, invited to this one.
  let(:invitee) { create(:admin_user, :without_admin_role, password: password, password_confirmation: password) }
  let!(:invitation) { create(:invitation, resource: store, email: invitee.email) }

  def accept(params = {}, headers: {})
    post "/api/v3/admin/auth/invitations/#{invitation.prefixed_id}/accept",
         params: { token: invitation.token }.merge(params), headers: headers
  end

  def bearer(user)
    { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
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
    other_account = bearer(create(:admin_user))

    expect { accept(headers: other_account) }.not_to change(Spree::RoleUser, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(Spree::Invitation.pending.exists?(invitation.id)).to be(true)
  end

  it 'finds the account for a differently cased address on the password path too' do
    invitation.update_column(:email, invitee.email.upcase)

    expect { accept({ password: password }) }.to change(Spree::RoleUser, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['user']['email']).to eq(invitee.email)
  end

  it 'accepts a signed-out invitee who gives the password' do
    accept({ password: password })

    expect(response).to have_http_status(:ok)
    expect(invitation.reload.status).to eq('accepted')
  end
end
