module Spree
  class UserSessionsController < ::Devise::SessionsController
    include Spree::Storefront::DeviseConcern

    protected

    def translation_scope
      'devise.user_sessions'
    end

    private

    def title
      Spree.t(:login)
    end
  end
end
