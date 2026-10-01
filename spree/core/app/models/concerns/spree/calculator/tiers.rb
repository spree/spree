module Spree
  class Calculator < Spree.base_class
    # A tier ladder for the tiered calculators: a list of
    # `{ "threshold" => "100.0", "value" => "10.0" }` objects, where the value
    # is a percentage or an amount depending on the calculator. A list rather
    # than a hash keyed by threshold, because JSON object keys are always
    # strings and a number key would not survive storage.
    module Tiers
      extend ActiveSupport::Concern

      included do
        preference :tiers, :array, default: [], parse_on_set: ->(value) { Tiers.normalize(value) }

        validate :preferred_tiers_content
      end

      # @param value [Object] tiers as an operator or API client sent them
      # @return [Object] an array of string-keyed hashes with numbers as exact
      #   decimal strings — the form JSON stores, so a fresh value compares
      #   equal to one read back — or the value unchanged when it is not a list
      #   of hashes, so validation can name the problem
      def self.normalize(value)
        return value unless value.is_a?(Array) && value.all? { |tier| tier.respond_to?(:to_h) && !tier.is_a?(Array) }

        value.map do |tier|
          tier.to_h.stringify_keys.to_h { |key, number| [key, decimal(number)&.as_json || number] }
        end
      end

      # @return [BigDecimal, nil] nil when the value is not a number
      def self.decimal(value)
        BigDecimal(value.to_s, exception: false)
      end

      # The value of the highest tier whose threshold the amount reaches.
      #
      # @param amount [Numeric]
      # @return [BigDecimal, nil] nil when the amount reaches no tier
      def tier_value_for(amount)
        tier_pairs.reverse_each.detect { |threshold, _| amount >= threshold }&.last
      end

      private

      # @return [Array<Array(BigDecimal, BigDecimal)>] threshold and value, lowest threshold first
      def tier_pairs
        preferred_tiers.map { |tier| [Tiers.decimal(tier['threshold']), Tiers.decimal(tier['value'])] }.sort_by(&:first)
      end

      def preferred_tiers_content
        tiers = preferred_tiers
        unless tiers.is_a?(Array) && tiers.all? { |tier| tier.is_a?(Hash) }
          return errors.add(:preferred_tiers, :should_be_list)
        end

        thresholds = tiers.map { |tier| Tiers.decimal(tier['threshold']) }
        values = tiers.map { |tier| Tiers.decimal(tier['value']) }

        errors.add(:preferred_tiers, :thresholds_should_be_positive_number) unless thresholds.all? { |threshold| threshold&.positive? }
        errors.add(:preferred_tiers, :thresholds_should_be_unique) unless thresholds.uniq.size == thresholds.size
        validate_tier_values(values)
      end
    end
  end
end
