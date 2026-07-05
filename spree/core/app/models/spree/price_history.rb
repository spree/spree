# frozen_string_literal: true

module Spree
  class PriceHistory < Spree.base_class
    belongs_to :price, class_name: 'Spree::Price'
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :currency, presence: true
    validates :recorded_at, presence: true

    scope :for_variant, ->(variant_id) { where(variant_id: variant_id) }
    scope :for_currency, ->(currency) { where(currency: currency) }
    scope :in_period, ->(from, to = Time.current) { where(recorded_at: from..to) }
    scope :recent, ->(days = 30) { in_period(days.days.ago) }

    def money
      Spree::Money.new(amount || 0, currency: currency)
    end

    def display_amount
      money.to_s
    end

    def amount_in_cents
      money.amount_in_cents
    end
  end
end
