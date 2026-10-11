module Spree
  module Api
    module V3
      module Admin
        # The Admin API's address: the shared one plus the second phone number
        # orders and customer address books keep.
        class AddressRequestSchema < Spree::Api::V3::AddressRequestSchema
          string :alternative_phone
        end
      end
    end
  end
end
