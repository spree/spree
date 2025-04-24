module Spree
  module Stores
    class SettingsDefaultsByCountry
      prepend Spree::ServiceModule::Base

      IMPERIAL = %w[US GB LR MM].freeze

      def call(code:)
        default_unit_system = unit_system(code)

        success(
          unit_system: default_unit_system,
          weight_unit: weight_unit(default_unit_system),
          timezone: timezone(code)
        )
      end

      private

      def unit_system(code)
        IMPERIAL.include?(code) ? :imperial : :metric
      end

      def weight_unit(unit_system)
        unit_system.to_s == 'metric' ? 'kg' : 'lb'
      end

      def timezone(code)
        case code
        when 'US', 'CA'
          'Central Time (US & Canada)'
        else
          Spree::CountryToTimezone.call(code: code).value
        end
      end
    end
  end
end
