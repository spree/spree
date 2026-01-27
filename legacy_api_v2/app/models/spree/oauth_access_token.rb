module Spree
  class OauthAccessToken < Spree.base_class
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

    self.table_name = 'spree_oauth_access_tokens'
  end
end
