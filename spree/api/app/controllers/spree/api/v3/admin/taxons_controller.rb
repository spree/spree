module Spree
  module Api
    module V3
      module Admin
        class TaxonsController < ResourceController
          protected

          def model_class
            Spree::Taxon
          end

          def serializer_class
            Spree.api.admin_taxon_serializer
          end
        end
      end
    end
  end
end
