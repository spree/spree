module Spree
  class VariantSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.variant_attributes
    attributes :id, :name, :sku, :price
  end
end
