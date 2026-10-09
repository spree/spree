module Spree
  # Decimal attributes written as a number or canonical decimal text
  # ("1234.56"). Text in any other shape raises Spree::Money::InvalidFormat,
  # which the API answers as `invalid_money_format`, instead of being read as
  # a wrong number the way Rails' cast reads "1,599.99" as 1 and "$10" as 0.
  #
  # The columns hold four decimals, so a value with more decimals than it may
  # carry is refused on validation rather than stored and left to drift: an
  # amount that changes hands keeps its currency's decimals, a unit price four,
  # a rate its column's scale.
  module CanonicalDecimals
    extend ActiveSupport::Concern

    private

    # nil when the record has no currency yet (a payment before its order),
    # which leaves the check to the record's own presence validations.
    def canonical_decimals_currency_places
      currency = try(:currency)
      Spree::Money::Rounding.precision(currency) if currency.present?
    rescue ActiveSupport::DelegationError
      nil
    end

    class_methods do
      # @param names [Array<Symbol>]
      # @param places [:currency, Integer, nil] decimals allowed: the record's
      #   currency's, a fixed count, or nil for no check
      # @param ignore_blank [Boolean] leave the attribute as it was when given a blank
      def canonical_decimals(*names, places: :currency, ignore_blank: false)
        names.each do |name|
          define_method("#{name}=") do |value|
            next if ignore_blank && value.blank?

            super(Spree::Money::Rounding.parse_decimal(value))
          rescue Spree::Money::InvalidFormat => error
            raise Spree::Money::InvalidFormat.new(error.message, field: name)
          end
        end

        return if places.nil?

        validate do
          allowed = places == :currency ? canonical_decimals_currency_places : places
          next if allowed.nil?

          names.each do |name|
            next unless will_save_change_to_attribute?(name)

            # Read before the column's scale rounds it away.
            raw = read_attribute_before_type_cast(name)
            value = raw.is_a?(Numeric) ? BigDecimal(raw.to_s) : self[name]
            next if value.nil? || value.round(allowed) == value

            errors.add(name, :too_many_decimals, count: allowed)
          end
        end
      end
    end
  end
end
