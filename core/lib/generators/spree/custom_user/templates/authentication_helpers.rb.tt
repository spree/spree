module Spree
  module CurrentUserHelpers
    def self.included(receiver)
      receiver.send :helper_method, :spree_current_user
    end

    def spree_current_user
      current_user
    end
  end

  module AuthenticationHelpers
    def self.included(receiver)
      receiver.send :helper_method, :spree_login_path
      receiver.send :helper_method, :spree_signup_path
      receiver.send :helper_method, :spree_logout_path
    end

    def spree_login_path
      main_app.login_path
    end

    def spree_signup_path
      main_app.signup_path
    end

    def spree_logout_path
      main_app.logout_path
    end
  end
end

ApplicationController.include Spree::AuthenticationHelpers
ApplicationController.include Spree::CurrentUserHelpers

Spree::Api::BaseController.include Spree::CurrentUserHelpers
