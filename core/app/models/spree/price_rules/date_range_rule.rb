module Spree
  module PriceRules
    class DateRangeRule < Spree::PriceRule
      preference :starts_at, :datetime, default: nil
      preference :ends_at, :datetime, default: nil
      preference :timezone, :string, default: 'UTC'

      def applicable?(context)
        date = context.date || Time.current
        date = date.in_time_zone(preferred_timezone)

        return false if preferred_starts_at && date < preferred_starts_at
        return false if preferred_ends_at && date > preferred_ends_at

        true
      end

      def self.description
        'Apply pricing within a specific date range'
      end
    end
  end
end
