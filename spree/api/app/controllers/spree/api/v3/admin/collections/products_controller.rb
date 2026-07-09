module Spree
  module Api
    module V3
      module Admin
        module Collections
          # Manages the products curated under a collection — the manual
          # membership half. Listing is ordered by the ProductCollection
          # position so the merchant's manual ordering round-trips; +reposition+
          # persists a drag-to-reorder. Automatic (rule-based) membership is
          # materialized by the rules, not managed here.
          class ProductsController < ResourceController
            scoped_resource :products

            # Skip the base single-resource load — membership actions resolve
            # the product against the collection's scope themselves (set_product).
            skip_before_action :set_resource
            before_action :set_product, only: [:destroy, :reposition]

            # POST /api/v3/admin/collections/:collection_id/products
            # Body: { product_id: 'prod_…' }
            def create
              product = product_scope.find_by_prefix_id!(params[:product_id])
              Spree::Collections::AddProducts.call(collections: [@parent_collection], products: [product])
              render json: serialize_resource(product), status: :created
            end

            # DELETE /api/v3/admin/collections/:collection_id/products/:id
            def destroy
              Spree::Collections::RemoveProducts.call(collections: [@parent_collection], products: [@product])
              head :no_content
            end

            # PATCH /api/v3/admin/collections/:collection_id/products/:id/reposition
            # Body: { new_position: 0 } — 0-based index among the collection's products.
            # @product is already constrained to the collection's scope, so a
            # ProductCollection always exists.
            def reposition
              position = integer_param(:new_position)
              return render_invalid_position if position.nil?

              product_collection_for(@product).insert_at(position + 1)
              head :no_content
            end

            protected

            def model_class
              Spree::Product
            end

            def serializer_class
              Spree.api.admin_product_serializer
            end

            # The collection's products, ordered by membership position.
            def scope
              product_scope.
                joins(:product_collections).
                where(Spree::ProductCollection.table_name => { collection_id: @parent_collection.id }).
                order(Spree::ProductCollection.table_name => { position: :asc })
            end

            # A product is curated at most once per collection (unique
            # [collection_id, product_id]), so the join can't duplicate rows —
            # DISTINCT is unnecessary and breaks Postgres ordering by position.
            def collection_distinct?
              false
            end

            # Loads the parent collection (runs before the base set_resource).
            def set_parent
              @parent_collection = Spree::Collection.accessible_by(current_ability, :update).
                            for_store(current_store).
                            find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent_collection)
            end

            private

            def set_product
              @product = scope.find_by_prefix_id!(params[:id])
            end

            def product_scope
              current_store.products.accessible_by(current_ability, :show)
            end

            def product_collection_for(product)
              Spree::ProductCollection.find_by(collection_id: @parent_collection.id, product_id: product.id)
            end
          end
        end
      end
    end
  end
end
