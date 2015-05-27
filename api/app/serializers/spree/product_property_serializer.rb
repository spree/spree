module Spree
  class ProductPropertySerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.product_property_attributes
    attributes :id, :product_id, :property_id, :value, :property_name
  end
end
