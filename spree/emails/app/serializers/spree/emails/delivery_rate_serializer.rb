module Spree
  module Emails
    class DeliveryRateSerializer < Spree::Api::V3::DeliveryRateSerializer
      typelize freight_summary: [:EmailFreightSummary, nullable: true]

      one :freight_summary, resource: Spree::Emails::FreightSummarySerializer
      one :delivery_method, resource: Spree::Emails::DeliveryMethodSerializer
    end
  end
end
