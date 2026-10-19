module Spree
  module Api
    module V3
      # An address offered to a cart's address step, carrying the book it came
      # out of. Only this listing needs the owner: everywhere else an address
      # appears the book is already known from the endpoint, and a purchase's
      # own snapshot belongs to no book at all.
      class SelectableAddressSerializer < AddressSerializer
        one :owner, resource: proc { Spree.api.address_owner_serializer }
      end
    end
  end
end
