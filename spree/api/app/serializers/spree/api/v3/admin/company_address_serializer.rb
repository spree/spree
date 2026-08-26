module Spree
  module Api
    module V3
      module Admin
        # An entry in a company node's address book. Admin-only shape; the
        # storefront self-service surface serializes the same record through
        # its own class.
        class CompanyAddressSerializer < Admin::AddressSerializer
          typelize label: [:string, nullable: true], company_id: :string,
                   default_billing: :boolean, default_shipping: :boolean

          attributes :label

          # An entry always belongs to a company, so this is never null.
          attribute :company_id do |address|
            address.owner.prefixed_id
          end

          attribute :default_billing do |address|
            address.owner.default_bill_address_id == address.id
          end

          attribute :default_shipping do |address|
            address.owner.default_ship_address_id == address.id
          end
        end
      end
    end
  end
end
