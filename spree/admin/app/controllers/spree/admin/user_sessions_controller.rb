module Spree
  module Admin
    class UserSessionsController < defined?(Devise::SessionsController) ? Devise::SessionsController : Spree::Admin::BaseController
      layout 'spree/minimal'

      # We need to overwrite this action because `return_to` url may be in a different domain
      # So we need to pass `allow_other_host` option to `redirect_to` method
      def create
        self.resource = warden.authenticate!(auth_options)
        set_flash_message!(:notice, :signed_in)
        sign_in(resource_name, resource)
        yield resource if block_given?
        redirect_to after_sign_in_path_for(resource), allow_other_host: true
      end

      protected

      def translation_scope
        'devise.user_sessions'
      end
    end
  end
end
