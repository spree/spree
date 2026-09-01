module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # A catalog's per-variant quantity terms — the narrowest of the
          # three levels a buyer's rules resolve through. The catalog-wide
          # default is a pair of fields on the catalog itself, so this
          # surface is strictly the overrides.
          class QuantityRulesController < BaseController
            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::CatalogQuantityRule
            end

            def serializer_class
              Spree.api.admin_catalog_quantity_rule_serializer
            end

            def scope
              @parent.quantity_rules
            end

            def parent_association
              :quantity_rules
            end

            def collection_includes
              [variant: :product]
            end

            # The variant resolves through this store's own products, so an
            # id belonging to another tenant is a 404 rather than a term
            # written against a variant the merchant does not sell.
            def permitted_params
              permitted = params.permit(:minimum_order_quantity, :order_multiple, :variant_id)

              if permitted.key?(:variant_id)
                permitted[:variant_id] = current_store.variants.find_by_prefix_id!(permitted[:variant_id]).id
              end

              permitted
            end
          end
        end
      end
    end
  end
end
