module Spree
  class OauthAccessToken < Base
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

    self.table_name = 'spree_oauth_access_tokens'
  end
end
