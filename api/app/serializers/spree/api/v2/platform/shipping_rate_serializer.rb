module Spree
  module Api
    module V2
      module Platform
        class ShippingRateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :shipment
          belongs_to :tax_rate
          belongs_to :shipping_method
        end
      end
    end
  end
end
