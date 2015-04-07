module Spree
  class CountrySerializer < ActiveModel::Serializer
    attributes :id, :iso_name, :iso, :iso3, :name, :numcode

    has_many :states
  end
end
