module Spree
  module Api
    module V3
      module Admin
        module Categories
          # Manages the products classified under a category — the manual
          # membership half of the old Rails admin's taxon "Products" panel.
          # Listing is ordered by the classification position so the merchant's
          # manual ordering round-trips; +reposition+ persists a drag-to-reorder.
          class ProductsController < ResourceController
            scoped_resource :products

            # Skip the base single-resource load — membership actions resolve
            # the product against the category's scope themselves (set_product).
            skip_before_action :set_resource
            before_action :set_product, only: [:destroy, :reposition]

            # POST /api/v3/admin/categories/:category_id/products
            # Body: { product_id: 'prod_…' }
            def create
              product = product_scope.find_by_prefix_id!(params[:product_id])
              Spree::Categories::AddProducts.call(categories: [@category], products: [product])
              render json: serialize_resource(product), status: :created
            end

            # DELETE /api/v3/admin/categories/:category_id/products/:id
            # Bulk removal goes through the existing
            # POST /products/bulk_remove_from_categories ({ ids, category_ids }).
            def destroy
              Spree::Categories::RemoveProducts.call(categories: [@category], products: [@product])
              head :no_content
            end

            # PATCH /api/v3/admin/categories/:category_id/products/:id/reposition
            # Body: { new_position: 0 } — 0-based index among the category's products.
            # @product is already constrained to the category's scope, so a
            # classification always exists.
            def reposition
              position = integer_param(:new_position)
              return render_invalid_position if position.nil?

              classification_for(@product).insert_at(position + 1)
              # insert_at shifts sibling positions, so refresh every product in the
              # category (manual sort reads position from the search index).
              @category.products.find_each(&:enqueue_search_index)
              head :no_content
            end

            protected

            def model_class
              Spree::Product
            end

            def serializer_class
              Spree.api.admin_product_serializer
            end

            # The category's products, ordered by classification position.
            def scope
              product_scope.
                joins(:product_categories).
                where(Spree::ProductCategory.table_name => { category_id: @category.id }).
                order(Spree::ProductCategory.table_name => { position: :asc })
            end

            # A product is classified at most once per taxon (unique [taxon_id,
            # product_id]), so the join can't duplicate rows — DISTINCT is
            # unnecessary and breaks Postgres ("ORDER BY position must appear in
            # the select list of a DISTINCT query").
            def collection_distinct?
              false
            end

            # Loads the parent category (runs before the base set_resource).
            # Scoped to +manual+ so automatic (rule-based) rows — hidden by the
            # categories CRUD controller and migrating to Spree::Collection — can't
            # have their membership listed or mutated through this endpoint.
            def set_parent
              @category = Spree::Category.manual.
                          accessible_by(current_ability, :update).
                          for_store(current_store).
                          find_by_prefix_id!(params[:category_id])
              authorize_parent!(@category)
            end

            private

            def set_product
              @product = scope.find_by_prefix_id!(params[:id])
            end

            def product_scope
              current_store.products.accessible_by(current_ability, :show)
            end

            def classification_for(product)
              Spree::ProductCategory.find_by(category_id: @category.id, product_id: product.id)
            end
          end
        end
      end
    end
  end
end
