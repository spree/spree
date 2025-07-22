module Spree
  class OauthApplication < Spree.base_class
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'spree_oauth_applications'

    before_validation :set_blank_for_redirect_uri

    # returns the last someone used this application
    #
    # @return [DateTime]
    def last_used_at
      access_tokens.order(:created_at).last&.created_at
    end

    private

    def set_blank_for_redirect_uri
      self.redirect_uri = '' if redirect_uri.nil?
    end
  end
end
