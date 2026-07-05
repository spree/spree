module Spree
  module AuthenticationHelpers
    def self.included(receiver)
      receiver.helper_method(
        :spree_current_user,
        :spree_login_path,
        :spree_signup_path,
        :spree_logout_path,
        :spree_forgot_password_path,
        :spree_edit_password_path,
        :spree_admin_login_path,
        :spree_admin_logout_path
      )
    end

    def spree_current_user
      send("current_#{Spree.user_class.model_name.singular_route_key}")
    end

    def spree_login_path(opts = {})
      new_session_path(Spree.user_class.model_name.singular_route_key, opts)
    end

    def spree_signup_path(opts = {})
      new_registration_path(Spree.user_class.model_name.singular_route_key, opts)
    end

    def spree_logout_path(opts = {})
      destroy_session_path(Spree.user_class.model_name.singular_route_key, opts)
    end

    def spree_forgot_password_path(opts = {})
      new_password_path(Spree.user_class.model_name.singular_route_key, opts)
    end

    def spree_edit_password_path(opts = {})
      edit_registration_path(Spree.user_class.model_name.singular_route_key, opts)
    end

    def spree_admin_login_path(opts = {})
      new_session_path(Spree.admin_user_class.model_name.singular_route_key, opts)
    end

    def spree_admin_logout_path(opts = {})
      destroy_session_path(Spree.admin_user_class.model_name.singular_route_key, opts)
    end
  end
end

ApplicationController.include Spree::AuthenticationHelpers if defined?(ApplicationController)
