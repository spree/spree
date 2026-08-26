module Spree
  module Api
    module V3
      # An entry in a company node's address book, as members manage it. The
      # entry is the address itself — what makes it a book entry is its owner,
      # so this adds only the label it is filed under and which defaults it
      # holds for its node.
      class CompanyAddressSerializer < AddressSerializer
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
