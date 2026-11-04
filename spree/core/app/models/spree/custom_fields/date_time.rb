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
               when String then zone.iso8601(iso8601_input(input))
               when ::Time, ::DateTime then input
               when ::Date then zone.local(input.year, input.month, input.day)
               end
        time&.to_time&.utc&.iso8601
      rescue ArgumentError
        nil
      end

      # A bare-date `max` takes in the whole of that day, as a bare-date filter does.
      def self.normalize_validation_bound(value, store: nil, rule: nil)
        day = if value.is_a?(String) && value.strip.match?(/\A\d{4}-\d{2}-\d{2}\z/)
                ::Date.iso8601(value.strip)
              elsif value.instance_of?(::Date)
                value
              end
        return super unless rule == 'max' && day

        next_day = canonical_value(day + 1, store: store)
        next_day && (Time.iso8601(next_day) - 1).utc.iso8601
      rescue ArgumentError
        nil
      end

      # A bare date compares against the whole day in the store's time zone, so
      # "on 2026-10-12" matches every instant of that day, and "after" starts
      # at the next one.
      def self.filter_conditions(predicate, input, store: nil)
        return super unless input.is_a?(String) && input.strip.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        day = ::Date.iso8601(input.strip)
        from, to = [day, day + 1].map { |date| canonical_value(date, store: store) }
        case predicate
        when 'eq' then [['gteq', from], ['lt', to]]
        when 'gt' then [['gteq', to]]
        when 'gteq' then [['gteq', from]]
        when 'lt' then [['lt', from]]
        when 'lteq' then [['lt', to]]
        end
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
