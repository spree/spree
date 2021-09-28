module Spree
  class OauthApplication < Base
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'spree_oauth_applications'
  end
end
