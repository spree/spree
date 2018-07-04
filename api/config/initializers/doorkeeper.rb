Doorkeeper.configure do
  orm :active_record
  use_refresh_token
  # api_only uncomment after release of new doorkeeper version

  resource_owner_authenticator { current_user }

  resource_owner_from_credentials do
    user = Spree.user_class.find_for_database_authentication(email: params[:username])
    user if user && user.valid_for_authentication? { user.valid_password?(params[:password]) }
  end

  use_refresh_token

  grant_flows %w(password)

  access_token_methods :from_bearer_authorization, :from_access_token_param
end
