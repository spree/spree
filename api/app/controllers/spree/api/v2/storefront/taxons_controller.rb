module Spree
  module Api
    module V2
      module Storefront
        class TaxonsController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::CollectionOptionsHelpers

          def index
            render_serialized_payload { serialize_collection(paginated_collection) }
          end

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          private

          def serialize_collection(collection)
            collection_serializer.constantize.new(
              collection,
              collection_options(collection)
            ).serializable_hash
          end

          def serialize_resource(resource)
            resource_serializer.constantize.new(
              resource,
              include: resource_includes,
              fields: sparse_fields
            ).serializable_hash
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_taxon_serializer
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_taxon_serializer
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_taxon_finder
          end

          def collection_options(collection)
            {
              links: collection_links(collection),
              meta: collection_meta(collection),
              include: resource_includes,
              fields: sparse_fields
            }
          end

          def paginated_collection
            collection_paginator.constantize.new(collection, params).call
          end

          def collection
            collection_finder.constantize.new(scope: scope, params: params).execute
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
