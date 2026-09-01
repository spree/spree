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
