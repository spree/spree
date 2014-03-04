module Spree
  class InventoryUnitSerializer < ActiveModel::Serializer
    attributes :id, :state, :shipment_id
  end
end