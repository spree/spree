module Spree
  class DeliveryMethodZone < Spree.base_class
    belongs_to :delivery_method, -> { with_deleted }, inverse_of: :delivery_method_zones, class_name: 'Spree::DeliveryMethod'
    belongs_to :delivery_zone, inverse_of: :delivery_method_zones, class_name: 'Spree::DeliveryZone'

    validates :delivery_method, uniqueness: { scope: :delivery_zone }
  end
end
