module Spree
  # Reads a flag the way people write one in params, CSV files and stored
  # preferences. Unlike ActiveModel::Type::Boolean, "no" and unrecognised text
  # are false rather than true, and nil is false rather than nil.
  module Boolean
    TRUE_VALUES = %w[1 t true on y yes].freeze

    def self.cast(value)
      case value
      when true, false then value
      when Numeric then !value.zero?
      when String, Symbol then TRUE_VALUES.include?(value.to_s.strip.downcase)
      else false
      end
    end
  end
end
