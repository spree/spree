module Spree
  module NumberGenerators
    # Pre-6.0 behaviour, kept as an opt-in: prefix + a fixed-width run of
    # random digits. Merchants choose this when they would rather not tell a
    # repeat customer how many orders the store took in between their two
    # purchases, and accept numbers that are harder to read back over a
    # phone.
    class Random < Base
      DEFAULT_LENGTH = 9

      # @param length [Integer] digits after the prefix
      def initialize(length: DEFAULT_LENGTH)
        @length = length
      end

      def generate(record)
        digits = SecureRandom.random_number(10**@length).to_s.rjust(@length, '0')

        "#{prefix_for(record)}#{digits}#{suffix_for(record)}"
      end
    end
  end
end
