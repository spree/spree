module Spree
  module Api
    module V3
      module Admin
        module Collections
          # The products curated under a collection — the uniform nested
          # membership surface (see Spree::Api::V3::Admin::ProductMembership),
          # plus per-member reposition: listing is ordered by the
          # ProductCollection position so the merchant's manual ordering
          # round-trips. Automatic (rule-based) membership is materialized by
          # the rules, not managed here.
          class ProductsController < ResourceController
            include Spree::Api::V3::Admin::ProductMembership

            scoped_resource :products

            before_action :ensure_manual_collection, only: [:create, :destroy, :reposition]
            before_action :set_product, only: [:reposition]

            # PATCH /api/v3/admin/collections/:collection_id/products/:id/reposition
            # Body: { new_position: 0 } — 0-based index among the collection's products.
            # @product is already constrained to the collection's scope, so a
            # ProductCollection always exists.
            def reposition
              position = integer_param(:new_position)
              return render_invalid_position if position.nil?

              product_collection_for(@product).insert_at(position + 1)
              # insert_at shifts sibling positions, so refresh every product in the
              # collection (manual sort reads position from the search index).
              @parent_collection.products.find_each(&:enqueue_search_index)
              head :no_content
            end

            protected

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

            def add_member_products(products)
              Spree::Collections::AddProducts.call(collections: [@parent_collection], products: products)
            end

            def remove_member_products(products)
              Spree::Collections::RemoveProducts.call(collections: [@parent_collection], products: products)
            end

            # Loads the parent collection (runs before the base set_resource).
            # Any collection resolves — listing (index) an automatic collection's
            # rule-materialized membership is valid. Manual-only curation is enforced
            # separately by +ensure_manual_collection+ on the write actions.
            def set_parent
              @parent_collection = Spree::Collection.
                            accessible_by(current_ability, parent_ability_action).
                            for_store(current_store).
                            find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent_collection)
            end

            private

            # Manual curation (add/remove/reposition) is invalid on automatic
            # collections: their membership is materialized from rules by
            # RegenerateProducts, so a manual change would be wiped on the next
            # regeneration. Listing (index) the materialized membership is fine.
            def ensure_manual_collection
              return if @parent_collection.manual?

              render_error(
                code: ERROR_CODES[:validation_error],
                message: Spree.t('api.errors.automatic_collection_curation',
                                 default: "Products of an automatic collection are managed by its rules and can't be curated manually"),
                status: :unprocessable_content
              )
            end

            def set_product
              @product = scope.find_by_prefix_id!(params[:id])
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
