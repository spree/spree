module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize firstname: 'string | null', lastname: 'string | null', full_name: :string,
                 address1: 'string | null', address2: 'string | null',
                 city: 'string | null', zipcode: 'string | null', phone: 'string | null',
                 company: 'string | null', state_abbr: 'string | null', state_name: 'string | null',
                 state_text: 'string | null', country_iso: :string, country_name: :string

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
