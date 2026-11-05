module Spree
  module Emails
    class ReturnSerializer < Spree::Api::V3::ReturnSerializer
      _attributes.delete(:custom_fields)

      without_display_money

      typelize refunded_total: :string

      # What was actually paid back — not the Store API's refund_total, which
      # is the figure the return was expected to refund.
      attribute :refunded_total do |return_record|
        Spree::Money::Rounding.format(return_record.refunded_total, return_record.currency)
      end

      many :returned_items,
           source: proc { return_line_items.filter_map(&:line_item).uniq },
           resource: Spree::Emails::LineItemSerializer

      # What is coming back, at the quantities the customer named — a partial
      # return lists only its share of each line.
      many :items,
           source: proc { return_line_items },
           resource: Spree::Emails::ParcelItemSerializer

      # Where the parcel goes.
      one :stock_location, resource: Spree::Emails::StockLocationSerializer
      typelize reason_name: [:string, nullable: true], memo: [:string, nullable: true]

      # The customer's own note. One staff wrote stays in the back office,
      # as the Store API keeps it.
      attribute :memo do |return_record|
        return_record.memo if return_record.acted_by_type(:created_by).nil?
      end

      attribute :reason_name do |return_record|
        return_record.reason&.name
      end
    end
  end
end
