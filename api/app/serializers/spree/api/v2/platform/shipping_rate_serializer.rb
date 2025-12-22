module Spree
  module Api
    module V2
      module Platform
        class ShippingRateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :shipment, serializer: Spree.api.platform_shipment_serializer
          belongs_to :tax_rate, serializer: Spree.api.platform_tax_rate_serializer
          belongs_to :shipping_method, serializer: Spree.api.platform_shipping_method_serializer
        end
      end
    end
  end
end
