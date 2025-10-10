module Spree
  module Api
    module V2
      module Platform
        class ShippingRateSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :shipment, serializer: Spree::Api::Dependencies.platform_shipment_serializer.constantize
          belongs_to :tax_rate, serializer: Spree::Api::Dependencies.platform_tax_rate_serializer.constantize
          belongs_to :shipping_method, serializer: Spree::Api::Dependencies.platform_shipping_method_serializer.constantize
        end
      end
    end
  end
end
