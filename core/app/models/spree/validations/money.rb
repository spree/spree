module Spree
  module Validations
    module Money
      MONEY_THRESHOLD  = 100_000_000
      MONEY_VALIDATION = {
        presence:     true,
        numericality: {
          greater_than: -MONEY_THRESHOLD,
          less_than:     MONEY_THRESHOLD,
          allow_blank:   true
        },
        format:       { with: /\A-?\d+(?:\.\d{1,2})?\z/, allow_blank: true }
      }.freeze

      POSITIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
        validation.fetch(:numericality)[:greater_than_or_equal_to] = 0
      end.freeze

      NEGATIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
        validation.fetch(:numericality)[:less_than_or_equal_to] = 0
      end.freeze
    end
  end
end
