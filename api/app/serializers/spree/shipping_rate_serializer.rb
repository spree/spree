module Spree
  class ShippingRateSerializer < ActiveModel::Serializer
    attributes :id, :name, :cost, :selected, :display_cost
  end
end