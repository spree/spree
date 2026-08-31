module Spree
  # Unit conversion for the physical measurements Spree stores: dimensions in
  # millimeters, centimeters, inches or feet, and weights in grams, kilograms,
  # pounds or ounces.
  #
  # Spree keeps measurements in whatever unit the merchant typed, next to the
  # unit itself, so any calculation combining two records has to normalize
  # first. Volume is where this stops being cosmetic — a carton measured in
  # inches has roughly sixteen times the cubic value of the same numbers read
  # as centimeters, so cubic meters derived from raw dimension columns are
  # wrong for most of the world.
  #
  # Stateless module functions over two unit tables, deliberately not a value
  # object: callers already hold a number and a unit string.
  module Measurement
    # Centimeters per unit of length.
    LENGTH_IN_CENTIMETERS = {
      'mm' => BigDecimal('0.1'),
      'cm' => BigDecimal('1'),
      'in' => BigDecimal('2.54'),
      'ft' => BigDecimal('30.48')
    }.freeze

    # Kilograms per unit of weight.
    WEIGHT_IN_KILOGRAMS = {
      'g' => BigDecimal('0.001'),
      'kg' => BigDecimal('1'),
      'lb' => BigDecimal('0.45359237'),
      'oz' => BigDecimal('0.028349523125')
    }.freeze

    CENTIMETERS_PER_METER = BigDecimal('100')

    DEFAULT_LENGTH_UNIT = 'cm'.freeze
    DEFAULT_WEIGHT_UNIT = 'kg'.freeze

    class << self
      # Converts a length to centimeters.
      #
      # @param value [Numeric, String, nil]
      # @param unit [String, nil] one of {LENGTH_IN_CENTIMETERS}'s keys; an
      #   unknown or blank unit is read as centimeters
      # @return [BigDecimal, nil] nil when the value is missing
      def to_centimeters(value, unit: DEFAULT_LENGTH_UNIT)
        convert(value, LENGTH_IN_CENTIMETERS, unit, DEFAULT_LENGTH_UNIT)
      end

      # Converts a weight to kilograms.
      #
      # @param value [Numeric, String, nil]
      # @param unit [String, nil] one of {WEIGHT_IN_KILOGRAMS}'s keys; an
      #   unknown or blank unit is read as kilograms
      # @return [BigDecimal, nil] nil when the value is missing
      def to_kilograms(value, unit: DEFAULT_WEIGHT_UNIT)
        convert(value, WEIGHT_IN_KILOGRAMS, unit, DEFAULT_WEIGHT_UNIT)
      end

      # The cubic meters a box of these dimensions occupies — the CBM figure
      # freight is quoted and tiered on.
      #
      # @param length [Numeric, nil]
      # @param width [Numeric, nil]
      # @param height [Numeric, nil]
      # @param unit [String, nil] the unit all three are expressed in
      # @return [BigDecimal, nil] nil unless all three dimensions are present
      #   and positive — a box with a missing or zero side has no volume worth
      #   reporting, and returning zero would read as "measured, and empty"
      def cubic_meters(length, width, height, unit: DEFAULT_LENGTH_UNIT)
        sides = [length, width, height].map { |side| to_centimeters(side, unit: unit) }
        return if sides.any? { |side| side.nil? || side <= 0 }

        sides.inject(:*) / (CENTIMETERS_PER_METER**3)
      end

      private

      def convert(value, table, unit, default_unit)
        return if value.nil? || (value.is_a?(String) && value.blank?)

        factor = table[unit.to_s.downcase.presence || default_unit] || table[default_unit]
        value.to_d * factor
      end
    end
  end
end
