module Spree
  module Api
    module V3
      module Admin
        module Collections
          # Products kept out of a collection, whatever its rules match or a
          # merchant picked. Excluding removes the product from the
          # collection; deleting the exclusion regenerates the collection,
          # which brings the product back if the rules still match.
          class ExclusionsController < ResourceController
            scoped_resource :collections

            request_params :collection_exclusion do |body|
              body.attribute :product_id, :id, required: true, example: 'prod_abc123',
                                               description: 'The product to keep out of the collection.'
            end

            protected

            def model_class
              Spree::CollectionExclusion
            end

            def serializer_class
              Spree.api.admin_collection_exclusion_serializer
            end

            def set_parent
              @parent = current_store.collections.accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent)
            end

            def scope_includes
              [:product]
            end

            # The product is looked up in the store, so another store's id is a 404.
            def build_resource
              product_id = permitted_params[:product_id]
              resource_scope.new.tap do |exclusion|
                exclusion.product = current_store.products.find_by_prefix_id!(product_id) if product_id.present?
              end
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end
          end
        end
      end
    end
  end
end
