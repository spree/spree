module Spree
  module Emails
    # A purchase that divided into several orders, as its confirmation reads
    # it: every item, the parcels it ships in, and one set of totals.
    class OrderGroupSerializer < Spree::Api::V3::OrderGroupSerializer
      attributes :po_number

      attribute :customer_name, &:name

      attribute :order_count do |group|
        group.orders.size
      end

      attribute :display_delivery_total do |group|
        group.display_delivery_total.to_s
      end

      attribute :delivery_total do |group|
        group.delivery_total.to_s
      end

      attribute :additional_tax_total do |group|
        group.additional_tax_total.to_s
      end

      attribute :display_additional_tax_total do |group|
        group.display_additional_tax_total.to_s
      end

      attribute :gift_card_total do |group|
        group.gift_card_total.to_s
      end

      attribute :display_gift_card_total do |group|
        group.display_gift_card_total.to_s
      end

      attribute :display_total_minus_store_credits do |group|
        group.display_total_minus_store_credits.to_s
      end

      many :line_items, key: :items, resource: Spree::Emails::LineItemSerializer

      many :fulfillment_groups, resource: Spree::Emails::FulfillmentGroupSerializer

      # What no parcel carries — a download, an emailed gift card.
      many :unfulfilled_items,
           source: proc { unfulfilled_line_items },
           resource: Spree::Emails::LineItemSerializer

      many :promotion_discounts,
           source: proc { Spree::Emails::AmountLine.group(discounts.promotion, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer

      many :manual_discounts,
           source: proc { Spree::Emails::AmountLine.group(discounts.manual, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer

      # One delivery row for the whole purchase; the parcels break it down.
      many :delivery_lines,
           source: proc { delivery_total.zero? ? [] : [Spree::Emails::AmountLine.new(amount: delivery_total, currency: currency)] },
           resource: Spree::Emails::AmountLineSerializer

      # The split apportions an order-level fee into one row per child, all
      # under one label; summed back, it is the one charge the customer saw.
      many :fee_lines,
           source: proc { Spree::Emails::AmountLine.group(fees, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer
    end
  end
end
