module Spree
  module Emails
    class ReturnSerializer < Spree::Api::V3::ReturnSerializer
      typelize refunded_total: :string, display_refunded_total: :string

      # What was actually paid back — not the Store API's refund_total, which
      # is the figure the return was expected to refund.
      attribute :refunded_total do |return_record|
        Spree::Money::Rounding.format(return_record.refunded_total, return_record.currency)
      end

      attribute :display_refunded_total do |return_record|
        return_record.display_refunded_total.to_s
      end

      many :returned_items,
           source: proc { return_line_items.filter_map(&:line_item).uniq },
           resource: Spree::Emails::LineItemSerializer
    end
  end
end
