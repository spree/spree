# This validator can be overridden to implement custom phone validation logic.
# Currently uses the phonelib gem to validate phone numbers and ensure they
# belong to the address country.

require 'phonelib'

module Spree
  module Addresses
    class PhoneValidator < ActiveModel::Validator
      def validate(address)
        return if !address.require_phone? || address.phone.blank? || address.country.blank? || address.country_iso.blank?

        phone = Phonelib.parse(address.phone)
        unless phone.valid_for_country?(address.country_iso)
          address.errors.add(:phone, :invalid)
        end
      end
    end
  end
end
