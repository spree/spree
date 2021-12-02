module Spree
  class OauthApplication < Base
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'spree_oauth_applications'

    before_validation :set_blank_for_redirect_uri

    private

    def set_blank_for_redirect_uri
      self.redirect_uri = '' if redirect_uri.nil?
    end
  end
end
