module Spree
  # One line on a {Spree::Return} — a quantity of a fulfilled item coming back.
  #
  # Named for {Spree::LineItem}, which it mirrors: `quantity` is what the
  # customer said was coming, `received_quantity` what the warehouse counted.
  class ReturnLineItem < Spree.base_class
    has_prefix_id :rli

    belongs_to :return, class_name: 'Spree::Return', inverse_of: :return_line_items
    belongs_to :fulfillment_item, class_name: 'Spree::FulfillmentItem'
    belongs_to :line_item, class_name: 'Spree::LineItem'
    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'

    validates :quantity, numericality: { greater_than: 0 }
    validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }
    validates :pre_tax_amount, numericality: { greater_than_or_equal_to: 0 }

    before_validation :set_defaults_from_line_item, on: :create

    delegate :order, :currency, to: :return

    def display_pre_tax_amount
      Spree::Money.new(pre_tax_amount, currency: currency)
    end

    private

    # The refundable amount defaults to this item's share of what the
    # customer actually paid for the line, after discounts — refunding the
    # list price would give back more than was taken.
    def set_defaults_from_line_item
      self.variant ||= line_item&.variant
      self.pre_tax_amount = default_pre_tax_amount if pre_tax_amount.blank? || pre_tax_amount.zero?
    end

    def default_pre_tax_amount
      return 0 if line_item.nil? || line_item.quantity.to_i.zero?

      (line_item.amount / line_item.quantity) * quantity.to_i
    end
  end
end
