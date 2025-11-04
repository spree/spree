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
            Spree::Api::Dependencies.v3_storefront_taxon_serializer.constantize
          end

          def scope
            Spree::Taxon
              .for_store(current_store)
              .includes(scope_includes)
          end

          def scope_includes
            [:taxonomy, :parent, :children]
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
