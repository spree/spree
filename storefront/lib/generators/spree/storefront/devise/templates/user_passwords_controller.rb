module Spree
  class UserPasswordsController < ::Devise::PasswordsController
    include Spree::Storefront::DeviseConcern

    protected

    def translation_scope
      'devise.user_passwords'
    end

    private

    def title
      Spree.t(:forgot_password)
    end
  end
end
