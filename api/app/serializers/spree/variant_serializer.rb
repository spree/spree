module Spree
  class VariantSerializer < ActiveModel::Serializer
    attributes :id, :name, :sku, :price
  end
end