module Spree
  module Emails
    class FulfillmentSerializer < Spree::Api::V3::FulfillmentSerializer
      attribute :delivery_method_name do |fulfillment|
        fulfillment.delivery_method&.name
      end

      many :manifest, key: :manifest_items, source: proc { manifest.select(&:line_item) },
                     resource: Spree::Emails::ParcelItemSerializer
    end
  end
end
