module Spree
  module DatabaseTypeUtilities
    # Maximum value for a 4-byte signed integer (default database integer type)
    INTEGER_MAX = (2**31) - 1

    def self.maximum_value_for(data_type)
      case data_type
      when :integer
        INTEGER_MAX
      else
        raise ArgumentError, 'Currently only :integer argument is acceptable'
      end
    end
  end
end
