module Spree
  module Api
    module V3
      module Admin
        # Read-only Markets surface for the admin SPA. Markets are
        # store-scoped (`store_id` column + `acts_as_list scope: :store_id`),
        # so the base ResourceController's `scope` chain narrows
        # appropriately when we restrict to `current_store.markets`.
        #
        # Why read-only: the admin SPA only needs Markets in order to
        # render labels for `MarketRule` rows and resolve the picker
        # dropdown. Full write surface (create/update/delete) lives in
        # the legacy Rails admin pending the broader Channel/Catalog
        # rework — see `docs/plans/6.0-channels-catalogs-b2b.md`.
        class MarketsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::Market
          end

          def serializer_class
            Spree.api.admin_market_serializer
          end

          def scope
            current_store.markets.accessible_by(current_ability, :show)
          end

          def collection_includes
            [:countries]
          end
        end
      end
    end
  end
end
