Doorkeeper.configure do
  orm :active_record
  use_refresh_token
  api_only

  resource_owner_authenticator { current_spree_user }

  resource_owner_from_credentials do
    user = Spree.user_class.find_for_database_authentication(email: params[:username])
    user if user&.valid_for_authentication? { user.valid_password?(params[:password]) }
  end

  admin_authenticator do |routes|
    current_spree_user&.has_spree_role?('admin') || redirect_to(routes.root_url)
  end

  grant_flows %w(password)

  access_token_methods :from_bearer_authorization, :from_access_token_param
end

Doorkeeper::AccessGrant.class_eval do
  self.table_name = 'spree_oauth_access_grants'
end

Doorkeeper::AccessToken.class_eval do
  self.table_name = 'spree_oauth_access_tokens'
end

Doorkeeper::Application.class_eval do
  self.table_name = 'spree_oauth_applications'
end
