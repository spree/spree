module Spree
  module Api
    module V3
      # The writable attributes of a nested address.
      #
      # One list rather than one per controller: an address is the same record
      # wherever it hangs, so a column added on one write path but missed on
      # another is dropped silently.
      module AddressParams
        ADDRESS_KEYS = [
          :first_name, :last_name, :company, :address1, :address2, :city,
          :postal_code, :zipcode, :phone, :country_code, :state_code, :state_name, :label
        ].freeze
      end
    end
  end
end
