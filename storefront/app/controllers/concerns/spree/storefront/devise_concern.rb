# This concern is used to include the necessary methods and helpers for the Devise controllers
# It is used to avoid repeating the same code in each controller
module Spree
  module Storefront
    module DeviseConcern
      extend ActiveSupport::Concern

      included do
        helper_method :title
        helper_method :stored_location
        layout 'spree/storefront'

        include Spree::Core::ControllerHelpers::Order
        include Spree::LocaleUrls
        include Spree::ThemeConcern
        include Spree::IntegrationsHelper if defined?(Spree::IntegrationsHelper)

        helper 'spree/wishlist'
        helper 'spree/currency'
        helper 'spree/locale'
        helper 'spree/storefront_locale'
        helper 'spree/integrations' if defined?(Spree::IntegrationsHelper)
      end

      def stored_location
        return unless defined?(after_sign_in_path_for)
        return unless defined?(store_location_for)
        return unless defined?(Devise)

        path = after_sign_in_path_for(Devise.mappings.keys.first)

        store_location_for(Devise.mappings.keys.first, path)

        path
      end

      def password_path(_resource_or_scope = nil)
        send("#{Spree.user_class.model_name.singular_route_key}_password_path")
      end
    end
  end
end
