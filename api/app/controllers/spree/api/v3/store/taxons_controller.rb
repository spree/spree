module Spree
  module Api
    module V3
      module Store
        class TaxonsController < Store::ResourceController
          protected

          def model_class
            Spree::Taxon
          end

          def serializer_class
            Spree.api.taxon_serializer
          end
        end
      end
    end
  end
end
