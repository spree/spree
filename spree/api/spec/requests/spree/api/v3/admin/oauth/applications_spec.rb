require 'spec_helper'

# The screen this feeds exists to decide whether to take access away, so it
# has to answer both halves: what the application may do, and who allowed it.
RSpec.describe 'Admin connected applications', type: :request do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:application) do
    store.oauth_applications.create!(
      name: 'Claude', redirect_uri: 'https://example.test/cb', confidential: false
    )
  end

  before { Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp') }

  def token_for(owner, scopes: 'read_products')
    Spree::OauthAccessToken.create!(
      application: application, resource_owner: owner, scopes: scopes,
      expires_in: 2.hours.to_i, resource: Spree::Api::Oauth.resource_identifier(:mcp)
    )
  end

  def list
    get '/api/v3/admin/oauth/applications', headers: { 'X-Spree-API-Key' => api_key.plaintext_token }
    JSON.parse(response.body)
  end

  it 'names who approved the application and when' do
    token = token_for(admin)

    row = list['data'].first

    expect(row['authorized_by']).to eq(admin.actor_label)
    expect(Time.iso8601(row['authorized_at'])).to be_within(2.seconds).of(token.created_at)
  end

  # A later token refreshes an existing grant; it does not change who gave
  # it, so the oldest live consent is the one still in force.
  it 'keeps naming the original approver after a refresh' do
    first = token_for(admin)
    token_for(create(:admin_user))

    expect(Time.iso8601(list['data'].first['authorized_at'])).
      to be_within(2.seconds).of(first.created_at)
  end

  # A refresh token outlives the access token beside it, so a client whose
  # access has lapsed can mint another at will. Dropping it from the list
  # would leave a merchant unable to revoke something that still works —
  # the opposite of what this screen is for.
  it 'still lists an application whose access expired but can refresh' do
    token = token_for(admin)
    token.update_columns(created_at: 3.hours.ago, refresh_token: SecureRandom.hex(16))

    expect(list['data'].map { |row| row['name'] }).to include('Claude')
  end

  it 'drops it once revoked' do
    token_for(admin).update!(revoked_at: Time.current)

    expect(list['data']).to be_empty
  end

  it 'lists only applications somebody actually connected' do
    store.oauth_applications.create!(
      name: 'Never connected', redirect_uri: 'https://example.test/cb', confidential: false
    )
    token_for(admin)

    expect(list['data'].map { |row| row['name'] }).to contain_exactly('Claude')
  end

  it 'reports what the live tokens grant, not the registration' do
    token_for(admin, scopes: 'read_products write_orders')

    expect(list['data'].first['scopes']).to include('write_orders', 'read_products')
  end

  it 'pages, so a store with many connections is not served in one response' do
    token_for(admin)

    expect(list['meta']).to include('page', 'count', 'pages')
  end

  describe 'revoking' do
    it 'stops the application working without deleting its registration' do
      raw = token_for(admin).token

      delete "/api/v3/admin/oauth/applications/#{application.prefixed_id}",
             headers: { 'X-Spree-API-Key' => api_key.plaintext_token }

      expect(response).to have_http_status(:no_content)
      expect(Spree::OauthAccessToken.by_token(raw)).not_to be_accessible
      expect(store.oauth_applications.find_by(name: 'Claude')).to be_present
    end
  end
end
