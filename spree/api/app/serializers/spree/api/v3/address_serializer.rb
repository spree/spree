module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize firstname: [:string, nullable: true], lastname: [:string, nullable: true], full_name: :string,
                 address1: [:string, nullable: true], address2: [:string, nullable: true],
                 city: [:string, nullable: true], zipcode: [:string, nullable: true], phone: [:string, nullable: true],
                 company: [:string, nullable: true], state_abbr: [:string, nullable: true], state_name: [:string, nullable: true],
                 state_text: [:string, nullable: true], country_iso: :string, country_name: :string

        attributes :firstname, :lastname, :full_name, :address1, :address2,
                   :city, :zipcode, :phone, :company, :country_name, :country_iso, :state_text,
                   :state_abbr

        # State name - used for countries without predefined states
        attribute :state_name do |address|
          address.state_name.presence || address.state&.name
        end
      end
    end
  end
end
