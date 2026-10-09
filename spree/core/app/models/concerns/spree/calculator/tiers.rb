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
        preference :tiers, :array, of: :object, properties: { threshold: :money, value: :decimal }, default: []

        validate :preferred_tiers_content
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

      # Tiers that are not numbers are skipped: validation refuses them on
      # save, but an unsaved calculator can still be asked to compute. Tiers
      # still in the pre-6.0 hash keyed by threshold, left by an upgrade that
      # could not convert them, keep discounting until they are converted.
      #
      # @return [Array<Array(BigDecimal, BigDecimal)>] threshold and value, lowest threshold first
      def tier_pairs
        tiers = preferred_tiers
        pairs = case tiers
                when Hash then tiers.to_a
                when Array then tiers.grep(Hash).map { |tier| tier.values_at('threshold', 'value') }
                else []
                end
        pairs.map { |threshold, value| [Tiers.decimal(threshold), Tiers.decimal(value)] }.select(&:all?).sort_by(&:first)
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
