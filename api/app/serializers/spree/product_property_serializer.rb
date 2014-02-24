module Spree
  class ProductPropertySerializer < ActiveModel::Serializer
    attributes :value, :property_name
  end
end
