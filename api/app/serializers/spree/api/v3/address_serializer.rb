module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize firstname: 'string | null', lastname: 'string | null', full_name: :string,
                 address1: 'string | null', address2: 'string | null',
                 city: 'string | null', zipcode: 'string | null', phone: 'string | null',
                 company: 'string | null', state_id: 'string | null',
                 state_text: 'string | null', country_id: :string,
                 country_iso: :string, country_name: :string

        attributes :firstname, :lastname, :full_name, :address1, :address2,
                   :city, :zipcode, :phone, :company, :state_id,
                   :state_text, :country_id, :country_iso, :country_name
      end
    end
  end
end
