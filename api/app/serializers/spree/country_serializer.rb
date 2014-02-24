module Spree
  class CountrySerializer < ActiveModel::Serializer
    attributes :id, :iso_name, :iso, :iso3, :name, :numcode
  end
end
