module Spree
  class StockLocationSerializer < ActiveModel::Serializer
    attributes :id, :name, :address1, :address2, :city, :state_id,
      :state_name, :country_id, :zipcode, :phone, :active

    has_one :country, serializer: SmallCountrySerializer
    has_one :state
  end
end