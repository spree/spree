module Spree
  # What an order would look like with a change set applied — computed by
  # Spree::OrderChanges::Preview and never persisted.
  #
  # `balance_delta` is the move in the order total: positive when the
  # customer would owe more, negative when they would be owed money back.
  class OrderChangePreview
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :currency, :string
    attribute :item_total, :decimal
    attribute :discount_total, :decimal
    attribute :delivery_total, :decimal
    attribute :tax_total, :decimal
    attribute :fee_total, :decimal
    attribute :total, :decimal
    attribute :previous_total, :decimal
    attribute :outstanding_balance, :decimal

    # @param order [Spree::Order] the order as it would be after the change
    # @param previous_total [BigDecimal] the order total before it
    # @return [Spree::OrderChangePreview]
    def self.from_order(order, previous_total:)
      new(
        currency: order.currency,
        item_total: order.item_total,
        discount_total: order.discount_total,
        delivery_total: order.delivery_total,
        tax_total: order.tax_total,
        fee_total: order.fee_total,
        total: order.total,
        previous_total: previous_total,
        outstanding_balance: order.outstanding_balance
      )
    end

    # @return [BigDecimal]
    def balance_delta
      total - previous_total
    end
  end
end
