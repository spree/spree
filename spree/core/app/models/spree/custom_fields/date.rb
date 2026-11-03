module Spree
  module CustomFields
    # A calendar date, stored as `YYYY-MM-DD`.
    class Date < Spree::CustomField
      include DateRules

      # @param input [String, ::Date, Time, nil]
      # @param store [Spree::Store, nil] unused; a date has no time zone
      # @return [String, nil] `YYYY-MM-DD`, or nil when the input is not a date
      def self.canonical_value(input, store: nil)
        date = case input
               when String then ::Date.iso8601(iso8601_input(input))
               when ::Date, ::Time then input.to_date
               end
        date&.iso8601
      rescue ArgumentError
        nil
      end

      private

      def invalid_value_error
        :invalid_date
      end
    end
  end
end
