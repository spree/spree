module Spree
  module V2
    module Storefront
      class AddressSerializer < BaseSerializer
        set_type :address

        attributes :firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :state_name,
                   :company, :country_name, :country_iso3

        attribute :state_code, &:state_abbr
      end
    end
  end
end
