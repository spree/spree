require 'spec_helper'

# Consent is where a person hands part of their authority to an agent. The
# whole arrangement rests on that being a narrowing, so the ceiling is the
# server's to apply — a client that asks for more, or a browser driven to
# post more, must not get it.
RSpec.describe 'Admin OAuth consent', type: :request do
  let(:store) { @default_store }
  let(:application) do
    store.oauth_applications.create!(
      name: 'Claude', redirect_uri: 'https://example.test/cb', confidential: false
    )
  end
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest('v' * 64), padding: false) }

  # Products only — nothing this role could cancel, refund or configure.
  let(:staffer) do
    create(:admin_user, :without_admin_role).tap do |user|
      role = create(:role, name: "products-only-#{SecureRandom.hex(4)}",
                           permissions: %w[read_products], resource: store)
      create(:role_user, user: user, role: role)
    end
  end

  def authorize_params(scope:)
    {
      client_id: application.uid, redirect_uri: application.redirect_uri,
      response_type: 'code', scope: scope,
      code_challenge: challenge, code_challenge_method: 'S256'
    }
  end

  def jwt_for(user)
    Spree::Api::V3::TestingSupport.generate_jwt(
      user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
    )
  end

  def approve(user, scope:)
    post '/api/v3/admin/oauth/authorize',
         params: authorize_params(scope: scope),
         headers: { 'Authorization' => "Bearer #{jwt_for(user)}" }
  end

  describe 'a scope the approver does not hold' do
    # A grant is a standing ceiling that outlives the moment it was given, so
    # recording more than the person held would widen on its own the day they
    # are promoted — without anyone approving anything.
    it 'is cut from the grant rather than recorded' do
      approve(staffer, scope: 'write_orders write_settings read_products')

      expect(response).to have_http_status(:ok)
      expect(Spree::OauthAccessGrant.order(:id).last.scopes.to_a).to contain_exactly('read_products')
    end

    it 'is not offered on the consent screen either' do
      get '/api/v3/admin/oauth/authorize',
          params: authorize_params(scope: 'write_orders read_products'),
          headers: { 'Authorization' => "Bearer #{jwt_for(staffer)}" }

      body = JSON.parse(response.body)
      expect(body['grantable_scopes']).to contain_exactly('read_products')
      expect(body['grantable_scopes']).not_to include('write_orders')
    end
  end

  # The merchant may hand over less than was asked for; that choice has to
  # survive, or the checkboxes are decoration.
  it 'honours a narrower selection than the client requested' do
    admin = create(:admin_user)

    approve(admin, scope: 'read_products')

    expect(Spree::OauthAccessGrant.order(:id).last.scopes.to_a).to contain_exactly('read_products')
  end
end
