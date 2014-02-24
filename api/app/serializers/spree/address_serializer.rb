module Spree
  class AddressSerializer < ActiveModel::Serializer
    attributes :firstname, :lastname, :full_name, :address1, :address2, :city,
      :zipcode, :phone, :company, :alternative_phone, :country_id, :state_id,
      :state_name

    def country
      object.country
    end

    def state
      object.state
    end
  end
end
