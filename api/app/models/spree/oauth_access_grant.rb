module Spree
  class OauthAccessGrant < Base
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant

    self.table_name = 'spree_oauth_access_grants'
  end
end
