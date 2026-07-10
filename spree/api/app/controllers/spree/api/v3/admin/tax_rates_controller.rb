module Spree
  module Api
    module V3
      module Admin
        class TaxRatesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::TaxRate
          end

          def serializer_class
            Spree.api.admin_tax_rate_serializer
          end

          def permitted_params
            params.permit(:name, :amount, :tax_category_id, :zone_id, :included_in_price)
          end
        end
      end
    end
  end
end
