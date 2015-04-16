module Spree
  class ShippingMethodSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.shipping_method_attributes
    attributes :id, :name, :code

    has_many :zones
    has_many :shipping_categories
  end
end
