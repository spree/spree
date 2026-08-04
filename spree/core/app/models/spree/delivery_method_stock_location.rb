module Spree
  # Restricts a delivery method to specific stock locations. For pickup
  # methods this is the configured pickup-location set; an empty set means
  # every pickup-enabled location qualifies.
  class DeliveryMethodStockLocation < Spree.base_class
    belongs_to :delivery_method, class_name: 'Spree::DeliveryMethod', inverse_of: :delivery_method_stock_locations
    belongs_to :stock_location, class_name: 'Spree::StockLocation'

    validates :delivery_method, :stock_location, presence: true
    validates :stock_location_id, uniqueness: { scope: :delivery_method_id }
  end
end
