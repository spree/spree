module Spree
  class DeliveryOriginGroupLocation < Spree.base_class
    belongs_to :delivery_origin_group, class_name: 'Spree::DeliveryOriginGroup',
               inverse_of: :delivery_origin_group_locations
    belongs_to :stock_location, class_name: 'Spree::StockLocation'

    validates :stock_location_id, uniqueness: { scope: :delivery_origin_group_id }
  end
end
