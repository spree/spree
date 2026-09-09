module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # The products curated into a catalog's assortment — the uniform
          # nested membership surface (see
          # Spree::Api::V3::Admin::ProductMembership). A catalog decides what
          # a buyer sees, never the order they see it in, so membership
          # carries no position and listing is ordered by name.
          class ProductsController < BaseController
            include Spree::Api::V3::Admin::ProductMembership

            before_action :authorize_parent_access!

            protected

            def serializer_class
              Spree.api.admin_catalog_product_serializer
            end

            # The resolver rides along in the serializer params, preloaded
            # with this page's variants: resolving row by row would be a query
            # per product, and the answer is the same for every row on the
            # page.
            # `expanded_keys` is the same dot-notation matching the serializer's
            # own `expand?` does, so the attribute never renders without the
            # resolver that fills it.
            def serializer_params
              params = super
              params = params.merge(catalog_price_resolver: catalog_price_resolver) if expanded_keys.include?('catalog_price')
              params = params.merge(catalog_quantity_rules: quantity_rules_by_product) if expanded_keys.include?('quantity_rule')
              params
            end

            # The page's quantity rules in one query, keyed by product. The
            # rows are stored per variant and read per product, which is the
            # roll-up the serializer does — on variants this page has already
            # loaded (docs/plans/6.0-volume-pricing.md).
            def quantity_rules_by_product
              @quantity_rules_by_product ||= begin
                variant_ids = priced_variants.map(&:id)
                rules = variant_ids.any? ? @catalog.quantity_rules.where(variant_id: variant_ids).to_a : []
                product_by_variant = priced_variants.to_h { |variant| [variant.id, variant.product_id] }

                rules.group_by { |rule| product_by_variant[rule.variant_id] }
              end
            end

            # Preloaded with every variant the page renders — each row now
            # prices its variants individually, so preloading only the buy-box
            # winner would leave the rest falling through to a query apiece
            # (docs/plans/6.0-volume-pricing.md).
            def catalog_price_resolver
              @catalog_price_resolver ||=
                Spree::Catalogs::ResolvePrices.new(catalog: @catalog, currency: current_currency).
                tap { |resolver| resolver.preload(priced_variants) }
            end

            def priced_variants
              Array(@collection).flat_map { |product| product.variants.to_a }
            end

            # Only what this page reads: the card's thumbnail, and every
            # variant with the rows and option values the resolver and the
            # variant rows need. `default_variant` is deliberately absent —
            # it is a separate `belongs_to` with a cache of its own, so
            # reading it here would re-query option values per row. Publications, stock levels and the default
            # variant's own prices are deliberately absent — this endpoint
            # serializes the membership shape, not a full admin product
            # (docs/plans/6.0-volume-pricing.md).
            def collection_includes
              [
                :primary_media,
                { variants: [:prices, { option_values: :option_type }] }
              ]
            end

            def scope
              product_scope.
                joins(:catalog_products).
                where(Spree::CatalogProduct.table_name => { catalog_id: @catalog.id }).
                order(:name)
            end

            # A product is curated at most once per catalog (unique
            # [catalog_id, product_id]), so the join can't duplicate rows and
            # DISTINCT is unnecessary.
            def collection_distinct?
              false
            end

            def add_member_products(products)
              @catalog.add_products(products.map(&:id))
            end

            # Through the model, so an owned price list drops the rows it
            # held for these products along with them.
            def remove_member_products(products)
              @catalog.remove_products(products.map(&:id))
            end
          end
        end
      end
    end
  end
end
