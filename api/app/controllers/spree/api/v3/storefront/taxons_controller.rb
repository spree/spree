module Spree
  module Api
    module V3
      module Storefront
        class TaxonsController < ResourceController
          # Public endpoint - no authentication required

          protected

          def model_class
            Spree::Taxon
          end

          def serializer_class
            Spree.api.v3_storefront_taxon_serializer
          end

          def scope
            Spree::Taxon.for_store(current_store)
          end

          # Not needed for index/show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end
