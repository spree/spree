module Spree
  module Api
    module V3
      # An entry in a company node's address book, as members manage it.
      class CompanyAddressSerializer < BaseSerializer
        typelize label: [:string, nullable: true], company_id: :string,
                 default_billing: :boolean, default_shipping: :boolean

        attributes :label, :default_billing, :default_shipping

        # An entry always belongs to a company, so this is never null.
        attribute :company_id do |entry|
          entry.company.prefixed_id
        end

        one :address, resource: proc { Spree.api.address_serializer }
      end
    end
  end
end
