module Spree
  module Api
    module V3
      # Store API store context: the publishable key selects the store (the
      # key belongs to exactly one store) — the request host is never
      # consulted. See docs/plans/6.0-store-context-and-first-run-setup.md.
      #
      # Included in both Store API branch anchors (Store::BaseController and
      # Store::ResourceController) alongside ApiKeyAuthentication, whose
      # memoized +publishable_api_key+ lookup this reads — pre-authentication
      # callbacks (channel resolution, locale fallbacks) resolve the same key
      # row authentication later verifies.
      module KeyStoreContext
        extend ActiveSupport::Concern

        included do
          # An invalid or missing key must render 401 from
          # +authenticate_api_key!+ — without this skip the store-presence
          # guard would 404 first on the ResourceController branch, where it
          # runs ahead of authentication.
          skip_before_action :raise_record_not_found_if_store_is_not_found
        end

        # @return [Spree::Store, nil]
        def current_store
          @current_store ||= publishable_api_key&.store
        end
      end
    end
  end
end
