module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize first_name: [:string, nullable: true], last_name: [:string, nullable: true], full_name: :string,
                 address1: [:string, nullable: true], address2: [:string, nullable: true],
                 city: [:string, nullable: true], postal_code: [:string, nullable: true], phone: [:string, nullable: true],
                 company: [:string, nullable: true], state_code: [:string, nullable: true],
                 state_abbr: [:string, nullable: true], state_name: [:string, nullable: true],
                 state_text: [:string, nullable: true], country_code: :string, country_iso: :string,
                 country_name: :string,
                 quick_checkout: :boolean, is_default_billing: :boolean, is_default_shipping: :boolean

        attributes :first_name, :last_name, :full_name, :address1, :address2, :postal_code,
                   :city, :phone, :company, :country_name, :country_code, :state_text,
                   :state_code, :quick_checkout, :is_default_billing, :is_default_shipping

        # @deprecated Storefronts shipped against these names; use +state_code+
        #   and +country_code+. Removed in 6.1.
        attribute :state_abbr, &:state_code
        attribute :country_iso, &:country_code

        # State name - used for countries without predefined states
        attribute :state_name do |address|
          address.state_name.presence || address.state&.name
        end
      end
    end
  end
end
