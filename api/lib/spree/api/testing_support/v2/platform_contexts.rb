shared_context 'Platform API v2' do
  let(:admin_app) { Doorkeeper::Application.find_or_create_by!(name: 'Admin Panel', scopes: 'admin', redirect_uri: '') }
  let(:read_app) { Doorkeeper::Application.find_or_create_by!(name: 'Read App', scopes: 'read', redirect_uri: '') }
  let(:oauth_token) do
    Doorkeeper::AccessToken.create!(
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end
  let(:read_oauth_token) do
    Doorkeeper::AccessToken.create!(
      application_id: read_app.id,
      scopes: read_app.scopes
    )
  end
  let(:user_oauth_token) do
    Doorkeeper::AccessToken.create!(
      resource_owner_id: user.id,
      application_id: admin_app.id,
      scopes: admin_app.scopes
    )
  end

  let(:valid_authorization) { "Bearer #{oauth_token.token}" }
  let(:valid_read_authorization) { "Bearer #{read_oauth_token.token}" }
  let(:valid_user_authorization) { "Bearer #{user_oauth_token.token}" }
  let(:bogus_authorization) { "Bearer #{::Base64.strict_encode64('bogus:bogus')}" }

  let(:Authorization) { valid_authorization }
end
