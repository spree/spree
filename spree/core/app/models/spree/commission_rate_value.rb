# frozen_string_literal: true

module Spree
  # What a commission rate charges in one currency, and the bounds it charges
  # within: a flat fee's +amount+, and a percentage's +min_amount+ floor and
  # +max_amount+ cap.
  #
  # An amount cannot travel the way a percentage can — "2" means nothing
  # without saying 2 of what — so a rate states one per currency rather than
  # having a figure converted on its behalf at sale time. A converted number
  # would drift daily against a fee the seller agreed to, and a cap that moves
  # is not a cap.
  class CommissionRateValue < Spree.base_class
    has_prefix_id :crval

    acts_as_paranoid

    belongs_to :commission_rate, class_name: 'Spree::CommissionRate'

    validates :currency, presence: true
    validates :amount, numericality: { greater_than_or_equal_to: 0 }
    validates :min_amount, :max_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :currency, uniqueness: { scope: [:commission_rate_id, *spree_base_uniqueness_scope] }
    validate :max_amount_above_min_amount

    normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

    extend Spree::DisplayMoney
    money_methods :amount, :min_amount, :max_amount

    # Whether this row states a floor or a cap, as opposed to only a flat fee.
    #
    # @return [Boolean]
    def bounded?
      min_amount.present? || max_amount.present?
    end

    private

    def max_amount_above_min_amount
      return if max_amount.nil? || min_amount.nil?
      return if max_amount >= min_amount

      errors.add(:max_amount, :must_be_greater_than_min_amount, message: Spree.t('errors.messages.must_be_greater_than_min_amount'))
    end
  end
end
