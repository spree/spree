require 'spec_helper'

# The token endpoint is where an authorization code becomes a credential, and
# nothing on the request has been authenticated yet — so it carries Spree's
# own throttle on top of Doorkeeper's checks.
RSpec.describe 'OAuth token endpoint', type: :request do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:application) do
    store.oauth_applications.create!(name: 'Probe', redirect_uri: 'https://example.test/callback',
                                     confidential: false)
  end

  def authorization_code
    verifier = 'v' * 64
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    jwt = Spree::Api::V3::TestingSupport.generate_jwt(
      admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
    )

    post '/api/v3/admin/oauth/authorize',
         params: { client_id: application.uid, redirect_uri: application.redirect_uri, response_type: 'code',
                   scope: 'read_products', code_challenge: challenge, code_challenge_method: 'S256' },
         headers: { 'Authorization' => "Bearer #{jwt}" }

    redirect = JSON.parse(response.body)['redirect_uri']
    [Rack::Utils.parse_query(URI.parse(redirect).query)['code'], verifier]
  end

  def exchange(code, verifier)
    post '/oauth/token', params: { grant_type: 'authorization_code', code: code, client_id: application.uid,
                                   redirect_uri: application.redirect_uri, code_verifier: verifier }
  end

  it 'exchanges a code for a token' do
    exchange(*authorization_code)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['access_token']).to be_present
  end

  it 'refuses a flood from one address' do
    allow(Rails.cache).to receive(:increment).and_return(Spree::Api::Config[:rate_limit_per_key] + 1)

    exchange('code', 'v' * 64)

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After']).to eq(Spree::Api::Config[:rate_limit_window].to_s)
    expect(JSON.parse(response.body)['error']).to eq('rate_limit_exceeded')
  end

  # Doorkeeper's token-info endpoint rendered the owner's raw database id and
  # Ruby class name, neither of which crosses the API anywhere else.
  it 'does not serve token info' do
    paths = Spree::Core::Engine.routes.routes.map { |route| route.path.spec.to_s }

    expect(paths).not_to include(a_string_including('token/info'))
  end
end
