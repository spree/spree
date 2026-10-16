module Spree
  module Api
    module V3
      module Admin
        class TaxExemptionReasonsController < ResourceController
          scoped_resource :settings

          request_params :tax_exemption_reason do |body|
            body.include_attributes Spree::Api::V3::Admin::ReasonRequestSchema
            body.attribute :code, :string, required: true, on: :create, example: 'resale',
              description: 'What certificates record and the tax provider receives — for Avalara, an entity use code such as `G`. ' \
                           'Fixed once a certificate records it.'
            body.attribute :metadata, :hash
          end

          protected

          def model_class
            Spree::TaxExemptionReason
          end

          def serializer_class
            Spree.api.admin_tax_exemption_reason_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
