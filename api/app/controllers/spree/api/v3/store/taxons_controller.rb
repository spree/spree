module Spree
  module Api
    module V3
      module Store
        class TaxonsController < ResourceController
          protected

          def model_class
            Spree::Taxon
          end

          def serializer_class
            Spree.api.v3_store_taxon_serializer
          end

          def scope
            Spree::Taxon.for_store(current_store)
          end
        end
      end
    end
  end
end
