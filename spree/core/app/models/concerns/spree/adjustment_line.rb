module Spree
  # Shared behavior of the typed adjustment lines (TaxLine, DiscountLine, Fee):
  # each carries a money amount with a label and attaches to exactly one
  # adjustable — a line item or a fulfillment.
  module AdjustmentLine
    extend ActiveSupport::Concern

    included do
      # Concrete adjustable — exactly one of these is set.
      # class_name flips to 'Spree::Fulfillment' when the Shipment rename lands.
      belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
      belongs_to :fulfillment, class_name: 'Spree::Shipment', optional: true

      validates :label, presence: true
      validate :exactly_one_adjustable

      scope :for_line_items, -> { where.not(line_item_id: nil) }
      scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }

      extend Spree::DisplayMoney
      money_methods :amount

      delegate :currency, to: :order
    end

    def adjustable
      line_item || fulfillment
    end

    private

    def exactly_one_adjustable
      if line_item.blank? && fulfillment.blank?
        errors.add(:base, Spree.t('errors.messages.must_belong_to_line_item_or_fulfillment'))
      elsif line_item.present? && fulfillment.present?
        errors.add(:base, Spree.t('errors.messages.cannot_belong_to_both_adjustables'))
      end
    end
  end
end
