module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize first_name: [:string, nullable: true], last_name: [:string, nullable: true], full_name: :string,
                 address1: [:string, nullable: true], address2: [:string, nullable: true],
                 city: [:string, nullable: true], postal_code: [:string, nullable: true], phone: [:string, nullable: true],
                 company: [:string, nullable: true], state_abbr: [:string, nullable: true], state_name: [:string, nullable: true],
                 state_text: [:string, nullable: true], country_iso: :string, country_name: :string,
                 quick_checkout: :boolean, is_default_billing: :boolean, is_default_shipping: :boolean

        attributes :first_name, :last_name, :full_name, :address1, :address2, :postal_code,
                   :city, :phone, :company, :country_name, :country_iso, :state_text,
                   :state_abbr, :quick_checkout, :is_default_billing, :is_default_shipping

        # State name - used for countries without predefined states
        attribute :state_name do |address|
          address.state_name.presence || address.state&.name
        end
      end
    end
  end
end
