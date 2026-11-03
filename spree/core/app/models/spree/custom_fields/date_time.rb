module Spree
  module CustomFields
    # An instant, stored in UTC as `YYYY-MM-DDTHH:MM:SSZ`. Input without an
    # offset is read in the store's time zone.
    class DateTime < Spree::CustomField
      include DateRules

      # @param input [String, Time, ::Date, nil]
      # @param store [Spree::Store, nil] whose time zone reads input without an offset
      # @return [String, nil] the UTC ISO 8601 form, or nil when the input is not a date and time
      def self.canonical_value(input, store: nil)
        zone = (store && Time.find_zone(store.preferred_timezone)) || Time.zone
        time = case input
               when String then zone.iso8601(input.strip)
               when ::Time, ::DateTime then input
               when ::Date then zone.local(input.year, input.month, input.day)
               end
        time&.to_time&.utc&.iso8601
      rescue ArgumentError
        nil
      end

      private

      def invalid_value_error
        :invalid_date_time
      end
    end
  end
end
