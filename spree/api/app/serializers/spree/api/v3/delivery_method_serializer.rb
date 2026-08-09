module Spree
  module Api
    module V3
      class DeliveryMethodSerializer < BaseSerializer
        typelize name: :string, code: [:string, nullable: true],
                 digital: :boolean, pickup: :boolean, pickup_point: :boolean,
                 estimated_transit_business_days_min: [:number, nullable: true],
                 estimated_transit_business_days_max: [:number, nullable: true]

        attributes :name, :code,
                   :estimated_transit_business_days_min, :estimated_transit_business_days_max

        # Derived from the fulfillment provider class — the storefront needs
        # the delivery kind to render the right checkout affordances.
        attribute :digital, &:digital?
        attribute :pickup, &:pickup?
        attribute :pickup_point, &:pickup_point?
      end
    end
  end
end
