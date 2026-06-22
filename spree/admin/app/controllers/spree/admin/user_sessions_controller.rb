module Spree
  module Admin
    class UserSessionsController < defined?(Devise::SessionsController) ? Devise::SessionsController : Spree::Admin::BaseController
      include Spree::Admin::AuthRateLimiting
      include Spree::Admin::LocaleConcern

      helper 'spree/locale'

      layout 'spree/minimal'

      # This controller inherits from Devise::SessionsController, so the
      # `set_locale` before_action from Spree::Core::ControllerHelpers::Locale
      # (mixed into Spree::Admin::BaseController) never runs here. Honor the
      # pre-auth `?locale=` param ourselves so the login screen's language
      # switcher works before any user is signed in, persisting the choice in a
      # cookie so it carries into the authenticated session after sign-in.
      before_action :set_login_locale

      auth_rate_limit :rate_limit_login, redirect_to: -> { new_session_path(resource_name) }

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

      private

      def set_login_locale
        pin_content_locale!

        # A supported `?locale=` is applied and persisted; an unsupported one is
        # ignored rather than shadowing an already-valid cookie. Falls back to
        # the cookie set on a previous visit.
        if supported_admin_locale?(params[:locale])
          cookies[ADMIN_LOCALE_COOKIE] = { value: params[:locale], expires: 1.year }
          I18n.locale = params[:locale]
        elsif supported_admin_locale?(admin_locale_cookie)
          I18n.locale = admin_locale_cookie
        end
      end
    end
  end
end
