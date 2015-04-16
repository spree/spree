module Spree
  class ShippingRateSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.shipping_rate_attributes
    attributes :id, :name, :cost, :selected, :display_cost, :shipping_method_code
  end
end
