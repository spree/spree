module Spree
  class ShippingMethodSerializer < ActiveModel::Serializer
    attributes :id, :name, :code

    has_many :zones
    has_many :shipping_categories
  end
end
