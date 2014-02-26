module Spree
  class ProductPropertySerializer < ActiveModel::Serializer
    attributes :id, :product_id, :property_id, :value, :property_name
  end
end
