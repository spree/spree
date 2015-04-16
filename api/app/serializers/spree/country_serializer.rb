module Spree
  class CountrySerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.country_attributes
    attributes :id, :iso_name, :iso, :iso3, :name, :numcode

    has_many :states
  end
end
