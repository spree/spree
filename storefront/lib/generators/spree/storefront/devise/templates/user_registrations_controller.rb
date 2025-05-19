module Spree
  class UserRegistrationsController < ::Devise::RegistrationsController
    include Spree::Storefront::DeviseConcern

    protected

    def translation_scope
      'devise.user_registrations'
    end

    private

    def title
      Spree.t(:sign_up)
    end
  end
end
