module Spree
  module Api
    module V3
      module Admin
        # Tax rates are the whole configuration of the internal tax provider, so
        # these endpoints are how the default engine is set up and inspected.
        class TaxRatesController < ResourceController
          scoped_resource :settings

          request_params :tax_rate do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'VAT', description: 'Customer-facing rate name.'
            body.attribute :rate, :decimal,
              example: '0.19',
              description: 'The rate as a fraction. Send this or `rate_percent`.'
            body.attribute :rate_percent, :decimal, example: '19', description: 'The rate as a percentage.'
            body.attribute :included_in_price, :boolean
            body.attribute :show_rate_in_label, :boolean
            body.attribute :tax_category_id, :id, required: true, on: :create
            body.attribute :country_code, :country,
              nullable: true,
              example: 'DE',
              description: 'ISO country code. A rate naming no country taxes everywhere.'
            body.attribute :state_code, :string,
              nullable: true,
              example: 'CA',
              description: 'State abbreviation within that country.'
            body.attribute :metadata, :hash
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
