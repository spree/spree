module Spree
  module Api
    module V3
      # A tax registration. Each endpoint publishes it under its own name
      # (`TaxIdentifierParams`, `SellerTaxIdentifierParams`). `kind` is
      # registry-driven, so a plain string: any kind is stored, and one with a
      # validator in Spree.tax_identifier_validators is checked by it.
      class TaxIdentifierRequestSchema < Spree::Api::V3::RequestSchema
        KIND_DESCRIPTION = 'The registration the number belongs to, such as `eu_vat` or `gb_vat`. ' \
                           'Any kind is accepted; one with a registered validator is checked by it. ' \
                           'Built-in: `eu_vat`. Extensions may register more.'.freeze

        attribute :kind, :string, required: true, example: 'eu_vat', description: KIND_DESCRIPTION
        attribute :value, :string, required: true, example: 'DE123456789'
      end
    end
  end
end
