module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        typelize_from Spree::Address
        typelize full_name: :string, state_text: 'string | null',
                 country_iso: :string, country_name: :string

        attributes :id, :firstname, :lastname, :full_name, :address1, :address2,
                   :city, :zipcode, :phone, :company, :state_id,
                   :state_text, :country_id, :country_iso, :country_name
      end
    end
  end
end
