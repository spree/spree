module Spree
  module Api
    module V2
      module Storefront
        class TaxonsController < ::Spree::Api::V2::BaseController
          def index
            @taxons = Spree::Taxon.includes(:children).accessible_by(current_ability, :read)
            @taxons = dependencies[:taxons_finder].new(@taxons, params).execute

            render json: serialize_taxons(@taxons), status: 200
          end

          def show
            @taxon = Spree::Taxon.find_by(id: params[:id])

            if @taxon
              render json: serialize_taxon(@taxon), status: 200
            else
              render json: { error: "Taxon doesn't exist" }, status: 422
            end
          end

          private

          def dependencies
            {
              taxons_finder:     Spree::Taxons::Find,
              taxon_serializer:  Spree::V2::Storefront::TaxonSerializer,
              taxons_serializer: Spree::V2::Storefront::TaxonSerializer
            }
          end

          private

          def serialize_taxon(taxon)
            dependencies[:taxon_serializer].new(taxon).serializable_hash
          end

          def serialize_taxons(taxons)
            dependencies[:taxons_serializer].new(taxons).serializable_hash
          end
        end
      end
    end
  end
end
