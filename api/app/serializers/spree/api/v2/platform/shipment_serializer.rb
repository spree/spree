module Spree
  module Api
    module V2
      module Platform
        class ShipmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :tracking_url

          belongs_to :order
          belongs_to :address
          belongs_to :stock_location
          has_many :adjustments
          has_many :inventory_units
          has_many :shipping_rates
          has_many :state_changes
          has_one :selected_shipping_rate, serializer: :shipping_rate, type: :shipping_rate
        end
      end
    end
  end
end
