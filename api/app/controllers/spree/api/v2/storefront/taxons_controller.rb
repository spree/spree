module Spree
  module Api
    module V2
      module Storefront
        class TaxonsController < ::Spree::Api::V2::ResourceController
          private

          def collection_serializer
            Spree::Api::Dependencies.storefront_taxon_serializer.constantize
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_taxon_serializer.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_taxon_finder.constantize
          end

          def paginated_collection
            @paginated_collection ||= collection_paginator.new(collection, params).call
          end

          def resource
            @resource ||= scope.find_by(permalink: params[:id]) || scope.find(params[:id])
          end

          def model_class
            Spree::Taxon
          end

          def scope_includes
            node_includes = %i[icon parent taxonomy]

            {
              parent: node_includes,
              children: node_includes,
              taxonomy: [root: node_includes],
              icon: [attachment_attachment: :blob]
            }
          end

          def serializer_params
            super.merge(include_products: action_name == 'show')
          end
        end
      end
    end
  end
end
