module Spree
  module Api
    module V3
      module Admin
        # A customer's or a company's tax registration, as staff write it.
        class TaxIdentifierRequestSchema < Spree::Api::V3::RequestSchema
          attribute :kind, :string,
            example: 'gb_vat',
            description: "#{Spree::Api::V3::TaxIdentifierRequestSchema::KIND_DESCRIPTION} Required when creating."
          attribute :value, :string, example: 'GB123456789', description: 'Required when creating.'
        end
      end
    end
  end
end
