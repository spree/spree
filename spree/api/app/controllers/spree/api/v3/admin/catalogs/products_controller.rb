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
          class ProductsController < ResourceController
            include Spree::Api::V3::Admin::ProductMembership

            scoped_resource :products

            protected

            def scope
              product_scope.
                joins(:catalog_products).
                where(Spree::CatalogProduct.table_name => { catalog_id: @parent_catalog.id }).
                order(:name)
            end

            # A product is curated at most once per catalog (unique
            # [catalog_id, product_id]), so the join can't duplicate rows and
            # DISTINCT is unnecessary.
            def collection_distinct?
              false
            end

            def add_member_products(products)
              @parent_catalog.add_products(products.map(&:id))
            end

            # Through the model, so an owned price list drops the rows it
            # held for these products along with them.
            def remove_member_products(products)
              @parent_catalog.remove_products(products.map(&:id))
            end

            def set_parent
              @parent_catalog = current_store.catalogs.
                                accessible_by(current_ability, parent_ability_action).
                                find_by_prefix_id!(params[:catalog_id])
              authorize_parent!(@parent_catalog)
            end
          end
        end
      end
    end
  end
end
