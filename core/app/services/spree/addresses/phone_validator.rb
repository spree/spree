# This validator can be overridden to implement custom phone validation logic.
# Currently uses the phonelib gem to validate phone numbers and ensure they
# belong to the configured default country.

module Spree
  module Addresses
    class PhoneValidator < ActiveModel::Validator
      def validate(address)
        return if address.phone.blank? || !Spree::Config[:address_requires_phone]

        phone = Phonelib.parse(address.phone)
        unless phone.valid? && Phonelib.default_country.include?(phone.country)
          address.errors.add(:phone, :invalid)
        end
      end
    end
  end
end
