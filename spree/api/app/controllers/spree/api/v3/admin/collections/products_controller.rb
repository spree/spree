module Spree
  module Api
    module V3
      module Admin
        module Collections
          # The products in a collection — the uniform nested membership
          # surface (see Spree::Api::V3::Admin::ProductMembership), plus
          # per-member reposition: listing is ordered by the ProductCollection
          # position so the merchant's manual ordering round-trips. Listing
          # covers rule-matched and hand-picked members; adding hand-picks a
          # product, and removing one a collection's rules still match brings
          # it back on regeneration (exclude it to keep it out).
          class ProductsController < ResourceController
            include Spree::Api::V3::Admin::ProductMembership

            scoped_resource :products

            before_action :set_product, only: [:reposition]

            request_params 'ProductMembershipRepositionParams', action: :reposition do |body|
              body.include_attributes Spree::Api::V3::Admin::ProductMembershipRepositionRequestSchema
            end

            # POST /api/v3/admin/collections/:collection_id/products
            # Members the rules matched are hand-picked in place, so they stay
            # when the rules stop matching; the rest are added as usual.
            def create
              ApplicationRecord.transaction do
                Spree::ProductCollection.hand_pick(collection_ids: @parent_collection.id,
                                                   product_ids: product_scope.where(id: decode_prefixed_ids(params[:product_ids])).select(:id))
                super
              end
            end

            # PATCH /api/v3/admin/collections/:collection_id/products/:id/reposition
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
            def set_parent
              @parent_collection = Spree::Collection.
                            accessible_by(current_ability, parent_ability_action).
                            for_store(current_store).
                            find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent_collection)
            end

            private

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
