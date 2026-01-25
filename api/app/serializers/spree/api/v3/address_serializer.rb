module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize firstname: 'string | null', lastname: 'string | null', full_name: :string,
                 address1: 'string | null', address2: 'string | null',
                 city: 'string | null', zipcode: 'string | null', phone: 'string | null',
                 company: 'string | null', state_code: 'string | null',
                 state_text: 'string | null', country_iso: :string, country_name: :string

        attributes :firstname, :lastname, :full_name, :address1, :address2,
                   :city, :zipcode, :phone, :company, :state_text, :country_name

        # Country code (ISO 3166-1 alpha-2)
        attribute :country_iso do |address|
          address.country_iso
        end

        # State code in ISO 3166-2 format (e.g., "US-CA", "DE-BY")
        attribute :state_code do |address|
          next nil unless address.state

          "#{address.country&.iso}-#{address.state.abbr}"
        end
      end
    end
  end
end
