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

        # The base serializer already reports these as is_default_billing /
        # is_default_shipping; the book surface has always named them without
        # the prefix, so both names answer the same predicate.
        attribute :default_billing, &:is_default_billing?
        attribute :default_shipping, &:is_default_shipping?
      end
    end
  end
end
