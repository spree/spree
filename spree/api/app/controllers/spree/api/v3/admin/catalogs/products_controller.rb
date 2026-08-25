module Spree
  module Api
    module V3
      module Admin
        module Catalogs
          # The products curated into a catalog's assortment. Listing is
          # ordered by the CatalogProduct position so the merchant's manual
          # ordering round-trips; +reposition+ persists a drag-to-reorder.
          class ProductsController < ResourceController
            include Spree::Api::V3::Admin::ProductListing

            scoped_resource :products

            # Skip the base single-resource load — membership actions resolve
            # the product against the catalog's scope themselves.
            skip_before_action :set_resource
            before_action :set_product, only: [:destroy, :reposition]

            # POST /api/v3/admin/catalogs/:catalog_id/products
            # Body: { product_ids: ['prod_…', …] } — bulk add, skipping rows
            # already present.
            def create
              product_ids = Array(params.require(:product_ids)).map do |id|
                Spree::Product.decode_prefixed_id(id) || id
              end
              added = @parent_catalog.add_products(product_scope.where(id: product_ids).ids)

              render json: { added_count: added }, status: :created
            end

            # DELETE /api/v3/admin/catalogs/:catalog_id/products/:id
            def destroy
              @parent_catalog.catalog_products.where(product_id: @product.id).destroy_all
              head :no_content
            end

            # PATCH /api/v3/admin/catalogs/:catalog_id/products/:id/reposition
            # Body: { new_position: 0 } — 0-based index within the assortment.
            def reposition
              position = integer_param(:new_position)
              return render_invalid_position if position.nil?

              @parent_catalog.catalog_products.find_by(product_id: @product.id).insert_at(position + 1)
              head :no_content
            end

            protected

            def model_class
              Spree::Product
            end

            def serializer_class
              Spree.api.admin_product_serializer
            end

            # The catalog's assortment, in the merchant's manual order.
            def scope
              product_scope.
                joins(:catalog_products).
                where(Spree::CatalogProduct.table_name => { catalog_id: @parent_catalog.id }).
                order(Spree::CatalogProduct.table_name => { position: :asc })
            end

            # A product is curated at most once per catalog (unique
            # [catalog_id, product_id]), so the join can't duplicate rows —
            # DISTINCT is unnecessary and breaks Postgres ordering by position.
            def collection_distinct?
              false
            end

            def set_parent
              @parent_catalog = current_store.catalogs.
                                accessible_by(current_ability, parent_ability_action).
                                find_by_prefix_id!(params[:catalog_id])
              authorize_parent!(@parent_catalog)
            end

            private

            def set_product
              @product = scope.find_by_prefix_id!(params[:id])
            end

            def product_scope
              current_store.products.accessible_by(current_ability, :show)
            end
          end
        end
      end
    end
  end
end
