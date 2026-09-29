module Spree
  module Emails
    # An order as its emails read it: the Store API order plus what only an
    # email shows — who to greet, the summary rows and line thumbnails.
    class OrderSerializer < Spree::Api::V3::OrderSerializer
      attribute :customer_name, &:name

      attribute :display_total_minus_store_credits do |order|
        order.display_total_minus_store_credits.to_s
      end

      many :line_items, key: :items, resource: Spree::Emails::LineItemSerializer

      many :promotion_discounts,
           source: proc { Spree::Emails::AmountLine.group(discounts.promotion, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer

      many :manual_discounts,
           source: proc { Spree::Emails::AmountLine.group(discounts.manual, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer

      # One row per delivery rate, at its cost before discounts, so the rows
      # add up to the total once a free-delivery promotion is listed.
      many :delivery_lines,
           source: proc {
             Spree::Emails::AmountLine.group(fulfillments, currency: currency, amount: :cost, keep_zero: true,
                                                           label: ->(fulfillment) { fulfillment.selected_delivery_rate&.name })
           },
           resource: Spree::Emails::AmountLineSerializer

      many :fee_lines,
           source: proc { Spree::Emails::AmountLine.group(fees, currency: currency) },
           resource: Spree::Emails::AmountLineSerializer
    end
  end
end
