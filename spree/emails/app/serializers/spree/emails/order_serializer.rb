module Spree
  module Emails
    # An order as its emails read it: the Store API order plus what only an
    # email shows — who to greet, the summary rows and line thumbnails.
    class OrderSerializer < Spree::Api::V3::OrderSerializer
      include Spree::Emails::PurchaseSummaryAttributes

      many :order_promotions, key: :discounts, resource: Spree::Emails::AppliedPromotionSerializer
      many :fees, resource: Spree::Emails::FeeSerializer
      many :fulfillments, resource: Spree::Emails::FulfillmentSerializer
      many :payments, resource: Spree::Emails::PaymentSerializer
      one :gift_card, resource: Spree::Emails::GiftCardSerializer
      one :market, resource: Spree::Emails::MarketSerializer

      # One row per delivery rate, at its cost before discounts, so the rows
      # add up to the total once a free-delivery promotion is listed.
      many :delivery_lines,
           source: proc {
             Spree::Emails::AmountLine.group(fulfillments, currency: currency, amount: :cost, keep_zero: true,
                                                           label: ->(fulfillment) { fulfillment.selected_delivery_rate&.name })
           },
           resource: Spree::Emails::AmountLineSerializer
    end
  end
end
