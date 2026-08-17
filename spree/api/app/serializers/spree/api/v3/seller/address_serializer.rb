module Spree
  module Api
    module V3
      module Seller
        # A seller's own address, as they see it.
        #
        # Identical to the storefront's — an address is an address — but it
        # lives in this namespace so the seller SDK generates its own type
        # rather than importing one from a package it does not depend on.
        class AddressSerializer < V3::AddressSerializer
        end
      end
    end
  end
end
