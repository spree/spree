module Spree
  class InventoryUnitSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.inventory_unit_attributes
    attributes :id, :state, :shipment_id
  end
end
