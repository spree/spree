module Spree
  class VariantSerializer < ActiveModel::Serializer
    attributes :id, :name, :sku, :price

    def price
      binding.pry
    end
  end
end