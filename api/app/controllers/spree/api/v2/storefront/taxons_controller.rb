module Spree
  module Api
    module V2
      module Storefront
        class TaxonsController < ::Spree::Api::V2::BaseController
          def index
            render json: serialize_taxons_collection(collection), status: 200
          end

          def show
            render json: serialize_taxon_resource(resource), status: 200
          end

          private

          def dependencies
            {
              taxons_finder:                Spree::Taxons::Find,
              taxon_resource_serializer:    Spree::V2::Storefront::TaxonSerializer,
              taxons_collection_serializer: Spree::V2::Storefront::TaxonSerializer
            }
          end

          def collection
            scope = Spree::Taxon.includes(:parent, :children).accessible_by(current_ability, :read)
            dependencies[:taxons_finder].new(scope, params).call
          end

          def resource
            Spree::Taxon.find_by(permalink: params[:id]) || Spree::Taxon.find(params[:id])
          end

          def serialize_taxon_resource(resource)
            dependencies[:taxon_resource_serializer].new(
              resource,
              include: resource_includes
            ).serializable_hash
          end

          def serialize_taxons_collection(collection)
            dependencies[:taxons_collection_serializer].new(collection).serializable_hash
          end

          def resource_includes
            request_includes || default_resource_includes
          end

          def default_resource_includes
            %i[
              parent
              taxonomy
              children
              products
              image
            ]
          end
        end
      end
    end
  end
end
