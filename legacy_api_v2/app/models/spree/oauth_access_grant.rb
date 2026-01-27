module Spree
  class OauthAccessGrant < Spree.base_class
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant

    self.table_name = 'spree_oauth_access_grants'
  end
end
