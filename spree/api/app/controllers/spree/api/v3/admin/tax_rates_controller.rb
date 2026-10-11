module Spree
  module Api
    module V3
      module Admin
        # Tax rates are the whole configuration of the internal tax provider, so
        # these endpoints are how the default engine is set up and inspected.
        class TaxRatesController < ResourceController
          scoped_resource :settings

          request_params 'TaxRateParams' do
            string :name, example: 'VAT', description: 'Customer-facing rate name.'
            decimal :rate, example: '0.19', description: 'The rate as a fraction. Send this or `rate_percent`.'
            decimal :rate_percent, example: '19', description: 'The rate as a percentage.'
            boolean :included_in_price, :show_rate_in_label
            id :tax_category_id
            string :country_code, nullable: true, example: 'DE',
                                  description: 'ISO country code. A rate naming no country taxes everywhere.'
            string :state_code, nullable: true, example: 'CA', description: 'State abbreviation within that country.'
            object :metadata
          end

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
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
