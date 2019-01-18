module Spree
  module Api
    module V2
      module Storefront
        module Account
          class OrdersController < ::Spree::Api::V2::BaseController
            include Spree::Api::V2::CollectionOptionsHelpers
            before_action :require_spree_current_user

            def index
              render_serialized_payload { serialize_collection(paginated_collection) }
            end

            def show
              spree_authorize! :show, resource

              render_serialized_payload { serialize_resource(resource) }
            end

            private

            def paginated_collection
              dependencies[:collection_paginator].new(sorted_collection, params).call
            end

            def sorted_collection
              dependencies[:collection_sorter].new(collection, params).call
            end

            def collection
              dependencies[:collection_finder].new(user: spree_current_user).execute
            end

            def resource
              resource = dependencies[:resource_finder].new(user: spree_current_user, number: params[:id]).execute.take
              raise ActiveRecord::RecordNotFound if resource.nil?

              resource
            end

            def serialize_collection(collection)
              dependencies[:collection_serializer].new(
                collection,
                collection_options(collection)
              ).serializable_hash
            end

            def serialize_resource(resource)
              dependencies[:resource_serializer].new(
                resource,
                include: resource_includes,
                sparse_fields: sparse_fields
              ).serializable_hash
            end

            def dependencies
              {
                collection_sorter: Spree::Orders::Sort,
                resource_finder: Spree::Orders::FindComplete,
                resource_serializer: Spree::V2::Storefront::CartSerializer,
                collection_serializer: Spree::V2::Storefront::CartSerializer,
                collection_finder: Spree::Orders::FindComplete,
                collection_paginator: Spree::Shared::Paginate
              }
            end

            def collection_options(collection)
              {
                links: collection_links(collection),
                meta: collection_meta(collection),
                include: resource_includes,
                sparse_fields: sparse_fields
              }
            end
          end
        end
      end
    end
  end
end
