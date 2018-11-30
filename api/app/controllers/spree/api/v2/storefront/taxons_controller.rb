module Spree
  module Api
    module V2
      module Storefront
        class TaxonsController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::CollectionOptionsHelpers

          def index
            render_serialized_payload serialize_collection(paginated_collection)
          end

          def show
            render_serialized_payload serialize_resource(resource)
          end

          private

          def serialize_collection(collection)
            dependencies[:collection_serializer].new(
              collection,
              collection_options(collection)
            ).serializable_hash
          end

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes
            ).serializable_hash
          end

          def dependencies
            {
              collection_finder: Spree::Taxons::Find,
              collection_paginator: Spree::Shared::Paginate,
              collection_serializer: Spree::V2::Storefront::TaxonSerializer,
              resource_serializer: Spree::V2::Storefront::TaxonSerializer
            }
          end

          def collection_options(collection)
            {
              links: collection_links(collection),
              meta: collection_meta(collection),
              include: resource_includes
            }
          end

          def paginated_collection
            dependencies[:collection_paginator].new(collection, params).call
          end

          def collection
            dependencies[:collection_finder].new(scope, params).call
          end

          def resource
            scope.find_by(permalink: params[:id]) || scope.find(params[:id])
          end

          def scope
            Spree::Taxon.accessible_by(current_ability, :read).includes(scope_includes)
          end

          def scope_includes
            node_includes = %i[icon products parent taxonomy]

            {
              parent: node_includes,
              children: node_includes,
              taxonomy: [root: node_includes],
              products: [],
              icon: []
            }
          end
        end
      end
    end
  end
end
