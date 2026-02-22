module Spree
  # @deprecated Use the integer constant directly instead, eg. `2_147_483_647` for 4-byte signed integer max.
  #   This module will be removed in Spree 5.5.
  module DatabaseTypeUtilities
    # Maximum value for a 4-byte signed integer (default database integer type)
    INTEGER_MAX = (2**31) - 1

    def self.maximum_value_for(data_type)
      Spree::Deprecation.warn(
        'Spree::DatabaseTypeUtilities.maximum_value_for is deprecated and will be removed in Spree 5.5. ' \
        'Use the integer constant directly instead, eg. 2_147_483_647 for 4-byte signed integer max.'
      )

      case data_type
      when :integer
        INTEGER_MAX
      else
        raise ArgumentError, 'Currently only :integer argument is acceptable'
      end
    end
  end
end
