module Spree
  module Api
    module V3
      class DeliveryMethodSerializer < BaseSerializer
        typelize name: :string, code: [:string, nullable: true], fulfillment_type: :string,
                 estimated_transit_business_days_min: [:number, nullable: true],
                 estimated_transit_business_days_max: [:number, nullable: true]

        attributes :name, :code, :fulfillment_type,
                   :estimated_transit_business_days_min, :estimated_transit_business_days_max
      end
    end
  end
end
