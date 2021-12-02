Doorkeeper.configure do
  orm :active_record
  use_refresh_token
  api_only
  base_controller 'Spree::Api::V2::BaseController'
  base_metal_controller 'Spree::Api::V2::BaseController'

  # FIXME: we should only skip this for Storefront API until v5
  # we should not skip this for Platform API
  skip_client_authentication_for_password_grant { true } if defined?(skip_client_authentication_for_password_grant)

  resource_owner_authenticator { current_spree_user }
  use_polymorphic_resource_owner

  resource_owner_from_credentials do
    user = Spree.user_class.find_for_database_authentication(email: params[:username])

    next if user.nil?

    if defined?(Spree::Auth::Config) && Spree::Auth::Config[:confirmable] == true
      user if user.active_for_authentication? && user.valid_for_authentication? { user.valid_password?(params[:password]) }
    elsif user&.valid_for_authentication? { user.valid_password?(params[:password]) }
      user
    end
  end

  admin_authenticator do |routes|
    current_spree_user&.spree_admin? || redirect_to(routes.root_url)
  end

  grant_flows %w[password client_credentials]

  allow_blank_redirect_uri true

  handle_auth_errors :raise

  access_token_methods :from_bearer_authorization, :from_access_token_param

  optional_scopes :admin, :write, :read

  access_token_class 'Spree::OauthAccessToken'
  access_grant_class 'Spree::OauthAccessGrant'
  application_class 'Spree::OauthApplication'

  # using Bcrupt for token secrets is currently not supported by Doorkeeper
  hash_token_secrets fallback: :plain
  hash_application_secrets fallback: :plain, using: '::Doorkeeper::SecretStoring::BCrypt'
end
