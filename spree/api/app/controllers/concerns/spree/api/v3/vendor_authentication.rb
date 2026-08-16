module Spree
  module Api
    module V3
      # Authentication for the marketplace seller panel.
      #
      # Deliberately not a subclass or variant of AdminAuthentication: a seller
      # holds no secret API key (keys are store-bound and grant `manage :all`),
      # so this surface is JWT-only and the key path simply does not exist here.
      module VendorAuthentication
        extend ActiveSupport::Concern

        included do
          after_action :set_no_store_cache
        end

        protected

        # Rejects an admin or storefront token before any vendor is resolved.
        def expected_audience
          Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_VENDOR
        end

        # Capability comes from the roles the seller holds *on this vendor*.
        # Passing the resource is what stops a store role — or the store's
        # `admin` super-role — being read here (see Spree::Ability).
        def ability_options
          { store: current_store, resource: current_vendor }
        end

        def authenticate_vendor!
          require_authentication!
        end

        def set_no_store_cache
          response.headers['Cache-Control'] = 'private, no-store'
        end
      end
    end
  end
end
