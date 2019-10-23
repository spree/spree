module Spree
  module V2
    module Storefront
      class AddressSerializer < BaseSerializer
        set_type :address

        attributes :firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :state_name,
                   :company, :country_name, :country_iso3, :country_iso

        attribute :state_code, &:state_abbr
        attribute :state_name, &:state_name_text
      end
    end
  end
end
