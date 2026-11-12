module Spree
  module Api
    module V3
      module Seller
        class AddressSerializer < V3::AddressSerializer
          # The Store API keeps these deprecated names until 6.1. A seller
          # keeps no address book of the buyer's, so has no owner to read.
          %i[state_abbr country_iso owner].each { |key| _attributes.delete(key) }
        end
      end
    end
  end
end
