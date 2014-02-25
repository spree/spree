module Spree
  class AddressSerializer < ActiveModel::Serializer
    attributes :firstname, :lastname, :full_name, :address1, :address2, :city,
      :zipcode, :phone, :company, :alternative_phone, :country_id, :state_id,
      :state_name, :country, :state

    has_one :country, serializer: Spree::SmallCountrySerializer
    has_one :state

  end
end
