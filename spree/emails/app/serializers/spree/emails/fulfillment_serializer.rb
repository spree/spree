module Spree
  module Emails
    class FulfillmentSerializer < Spree::Api::V3::FulfillmentSerializer
      typelize delivery_method_name: [:string, nullable: true]

      attribute :delivery_method_name do |fulfillment|
        fulfillment.delivery_method&.name
      end

      many :deliveries, resource: Spree::Emails::DeliverySerializer
      one :delivery_method, resource: Spree::Emails::DeliveryMethodSerializer
      one :stock_location, resource: Spree::Emails::StockLocationSerializer
      many :delivery_rates, resource: Spree::Emails::DeliveryRateSerializer

      many :manifest, key: :manifest_items, source: proc { manifest.select(&:line_item) },
                     resource: Spree::Emails::ParcelItemSerializer
    end
  end
end
