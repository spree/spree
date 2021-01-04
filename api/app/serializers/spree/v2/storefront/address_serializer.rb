module Spree
  module V2
    module Storefront
      class AddressSerializer < BaseSerializer
        set_type :address

        attributes :firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :state_name,
                   :company, :country_name, :country_iso3, :country_iso, :label

        attribute :state_code do |address|
          address.state_abbr
        end

        attribute :state_name do |address|
          address.state_name_text
        end
      end
    end
  end
end
