# frozen_string_literal: true

module Spree
  # What a flat-fee commission rate charges in one currency.
  #
  # A flat fee cannot travel the way a percentage can — "2" means nothing
  # without saying 2 of what — so a rate states an amount per currency rather
  # than having one converted on its behalf at sale time. A rate is skipped
  # for a currency it has no amount for, which is what stops a marketplace
  # accidentally charging a euro figure against a dollar sale.
  class CommissionRateValue < Spree.base_class
    has_prefix_id :crval

    acts_as_paranoid

    belongs_to :commission_rate, class_name: 'Spree::CommissionRate'

    validates :currency, presence: true
    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    validates :currency, uniqueness: { scope: [:commission_rate_id, *spree_base_uniqueness_scope] }

    normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

    extend Spree::DisplayMoney
    money_methods :amount
  end
end
