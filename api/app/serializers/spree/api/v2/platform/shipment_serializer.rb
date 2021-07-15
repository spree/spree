module Spree
  module Api
    module V2
      module Platform
        class ShipmentSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          set_type :shipment

          attributes :number, :final_price, :display_final_price,
                     :state, :shipped_at, :tracking_url

          attribute :free do |shipment|
            shipment.free?
          end

          has_many :shipping_rates

          belongs_to :stock_location
        end
      end
    end
  end
end
