require 'spec_helper'

# End-to-end over real HTTP: the link in the email, then the two endpoints it
# leads to. Unit specs cover the controller in isolation; this proves the
# routes are mounted and reachable as the mail addresses them.
RSpec.describe 'seller invitation flow', type: :request do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  # Carries the seller's seeded role, exactly as `Seller::TeamController`
  # creates it — that role is what `after_accept` turns into membership.
  let(:invitation) do
    create(:invitation, resource: seller, inviter: create(:admin_user),
                        email: 'joiner@example.com', role: seller.default_user_role)
  end

  it 'walks the emailed link through to a signed-in seller session' do
    Spree::Config[:seller_panel_url] = 'https://sellers.example.com'
    url = Rails.application.routes.url_helpers.admin_invitation_acceptance_url(invitation)
    expect(url).to start_with('https://sellers.example.com/accept-invitation/')

    get "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/lookup",
        params: { token: invitation.token }
    expect(response).to have_http_status(:ok)

    post "/api/v3/seller/auth/invitations/#{invitation.prefixed_id}/accept",
         params: { token: invitation.token, password: 'sekrit123', password_confirmation: 'sekrit123' }
    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)

    # The token must work on the seller API it was issued for.
    get '/api/v3/seller/me', headers: {
      'Authorization' => "Bearer #{body['token']}",
      'X-Spree-Seller-Id' => seller.prefixed_id
    }
    me = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(me['permission_keys']).to be_present
  ensure
    Spree::Config[:seller_panel_url] = nil
  end
end
