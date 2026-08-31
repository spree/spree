module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # A catalog's per-product quantity terms, written as a set.
          #
          # Terms are stored per variant but edited per product, because that
          # is the grain a merchant states them at ("minimum 48 of this
          # product"). One request per save rather than one per row: the
          # dashboard stages every edit behind the catalog's Save, and a
          # partial application would leave an agreement half-changed.
          class ProductTermsController < BaseController
            before_action :authorize_parent_access!

            # GET /api/v3/admin/catalogs/:catalog_id/product_terms
            def index
              render json: { data: serialize_terms }
            end

            # PUT /api/v3/admin/catalogs/:catalog_id/product_terms
            #
            # { terms: { "prod_abc": { minimum_order_quantity: 48,
            #                          order_multiple: 24 } } }
            #
            # A product whose pair is both null has its terms cleared.
            def upsert
              authorize! :update, @catalog

              result = Spree::Catalogs::SetProductTerms.call(catalog: @catalog, terms: resolved_terms)

              if result.success?
                render json: { data: serialize_terms }
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

            # Grouped by product, which is how the dashboard reads them back.
            def serialize_terms
              @catalog.quantity_rules.includes(variant: :product).group_by { |rule| rule.variant.product }.
                map { |product, rules| Spree::Catalogs::ProductTerm.new(product: product, rules: rules) }.
                map { |term| Spree.api.admin_catalog_product_term_serializer.new(term, params: serializer_params).to_h }
            end
          end
        end
      end
    end
  end
end
