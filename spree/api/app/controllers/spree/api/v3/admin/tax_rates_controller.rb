module Spree
  module Api
    module V3
      module Admin
        # Tax rates are the whole configuration of the internal tax provider, so
        # these endpoints are how the default engine is set up and inspected.
        class TaxRatesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::TaxRate
          end

          def serializer_class
            Spree.api.admin_tax_rate_serializer
          end

          def collection_includes
            [:tax_category]
          end

          def permitted_params
            params.permit(:name, :amount, :amount_percentage, :included_in_price,
                          :show_rate_in_label, :tax_category_id,
                          :country_iso, :state_code, metadata: {})
          end
        end
      end
    end
  end
end
