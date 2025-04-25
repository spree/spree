module Spree
  module Admin
    class UserPasswordsController < defined?(Devise::PasswordsController) ? Devise::PasswordsController : Spree::Admin::BaseController
      layout 'spree/minimal'

      def create
        self.resource = resource_class.send_reset_password_instructions(resource_params)
        yield resource if block_given?

        set_flash_message(:notice, :send_instructions) if is_navigational_format?
        # Don't not show error message that the email was not found
        respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
      end

      protected

      def translation_scope
        'devise.user_passwords'
      end
    end
  end
end
