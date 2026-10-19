module Spree
  module Api
    module V3
      # Which address book an entry came out of. A checkout offering the
      # buyer's own addresses beside their company's sites has to label the
      # two, and the owner is the only thing that tells a warehouse from
      # somebody's flat.
      class AddressOwnerSerializer < BaseSerializer
        typelize type: [:string, enum: %w[customer company], enum_type_name: 'AddressOwnerType'],
                 name: [:string, nullable: true]

        attribute :type do |owner|
          Spree::Base.polymorphic_api_type(owner.class.to_s)
        end

        # What to call the book. A company node answers with its own name, so
        # a division's own sites and the headquarters sites it inherits are
        # told apart rather than filed under one heading. A customer's book is
        # the caller's own and needs no name — "your addresses" is the client's
        # word for it, in the shopper's language.
        attribute :name do |owner|
          owner.name if owner.is_a?(Spree::Company)
        end
      end
    end
  end
end
