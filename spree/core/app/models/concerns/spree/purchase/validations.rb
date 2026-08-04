module Spree
  module Purchase
    # Column-level validations shared by Spree::Cart and Spree::Order: the
    # money-column battery and item counts. Email validation stays
    # host-specific (orders require one via require_email; carts validate
    # shape only, with presence enforced by Checkout::Requirements) — as do
    # the order-only status inclusions.
    module Validations
      extend ActiveSupport::Concern

      MONEY_THRESHOLD  = 100_000_000
      MONEY_VALIDATION = {
        presence: true,
        numericality: {
          greater_than: -MONEY_THRESHOLD,
          less_than: MONEY_THRESHOLD,
          allow_blank: true
        },
        format: { with: /\A-?\d+(?:\.\d{1,2})?\z/, allow_blank: true }
      }.freeze

      POSITIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
        validation.fetch(:numericality)[:greater_than_or_equal_to] = 0
      end.freeze

      NEGATIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
        validation.fetch(:numericality)[:less_than_or_equal_to] = 0
      end.freeze

      included do
        validates :total_quantity, presence: true,
                                   numericality: { greater_than_or_equal_to: 0, less_than: 2**31, only_integer: true, allow_blank: true }

        validates :item_total,           POSITIVE_MONEY_VALIDATION
        validates :adjustment_total,     MONEY_VALIDATION
        validates :included_tax_total,   POSITIVE_MONEY_VALIDATION
        validates :additional_tax_total, POSITIVE_MONEY_VALIDATION
        validates :payment_total,        MONEY_VALIDATION
        validates :delivery_total,       MONEY_VALIDATION
        validates :discount_total,       NEGATIVE_MONEY_VALIDATION
        validates :total,                MONEY_VALIDATION
      end
    end
  end
end
