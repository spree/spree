module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # A catalog's quantity terms — the narrowest of the three levels a
          # buyer's rules resolve through. The catalog-wide default is a pair
          # of fields on the catalog itself, so this surface is strictly the
          # overrides.
          #
          # Rows are stored per variant and written as a whole set, because
          # that is the grain a merchant states them at ("minimum 48 of this
          # product") and the dashboard stages every edit behind the catalog's
          # Save — a partial application would leave an agreement half-changed.
          #
          # There is no read action: the rules are read back on the assortment
          # rows (`expand=quantity_rule` on this catalog's products), which
          # already hold the variants they roll up
          # (docs/plans/6.0-volume-pricing.md).
          class QuantityRulesController < BaseController
            before_action :authorize_parent_access!

            # PUT /api/v3/admin/catalogs/:catalog_id/quantity_rules
            #
            # { terms: { "prod_abc": { minimum_order_quantity: 48,
            #                          order_multiple: 24 } } }
            #
            # A product whose pair is both null has its terms cleared.
            def upsert
              authorize! :update, @catalog

              result = Spree::Catalogs::SetProductTerms.call(catalog: @catalog, terms: resolved_terms)

              if result.success?
                head :no_content
              else
                render_service_error(result)
              end
            end

            protected

            def model_class
              Spree::CatalogQuantityRule
            end

            def serializer_class
              Spree.api.admin_catalog_quantity_rule_serializer
            end

            def scope
              @catalog.quantity_rules
            end

            def parent_association
              :quantity_rules
            end

            private

            # Products resolve through this store, so an id belonging to
            # another tenant is a 404 rather than a term written against a
            # product the merchant does not sell.
            def resolved_terms
              params.require(:terms).to_unsafe_h.to_h do |product_id, values|
                product = current_store.products.find_by_prefix_id!(product_id)
                [product, values.to_h.symbolize_keys.slice(:minimum_order_quantity, :order_multiple)]
              end
            end
          end
        end
      end
    end
  end
end
