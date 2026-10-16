module Spree
  module Api
    module V3
      module Admin
        class TaxExemptionReasonCodeGroupSerializer < V3::BaseSerializer
          # A value object, not a record — it has no id of its own.
          _attributes.delete(:id)

          typelize provider: [:string, nullable: true, comment: 'The tax provider that understands these codes, e.g. `Avalara AvaTax`; null for the default list.']

          attributes :provider

          many :reason_codes, resource: proc { Spree.api.admin_tax_exemption_reason_code_serializer }
        end
      end
    end
  end
end
